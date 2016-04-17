defmodule McEx.Chunk do
  use GenServer
  alias McEx.Net.Connection.Write
  alias McChunk.Chunk
  alias McProtocol.Packet.Server

  def start_link(world_id, pos, opts \\ []) do
    GenServer.start_link(__MODULE__, {world_id, pos}, opts)
  end

  def send_chunk(server, writer) do
    GenServer.cast(server, {:send_chunk, writer})
  end
  def stop_chunk(server) do
    GenServer.cast(server, :stop_chunk)
  end

  def init({world_id, pos}) do
    McEx.Registry.reg_chunk_server(world_id, pos)

    # Do actual chunk generation outside of init.
    # This prevents us from blocking for longer than is needed.
    GenServer.cast(self, :gen_chunk)

    {:ok, %{
        world_id: world_id,
        chunk_resource: nil,
        pos: pos}}
  end

  defp gen_chunk({:chunk, cx, cz}) do
    data = McEx.Native.Chunk.gen_chunk_raw({cx, cz})
    {sections, ""} = Enum.reduce(0..15, {[], data}, fn sy, {sections, data} ->
      <<section_blocks::binary-size(4096), data::binary>> = data
      section = McChunk.Section.new_from_old(section_blocks)
      {[section | sections], data}
    end)
    %Chunk{Chunk.new | sections: Enum.reverse(sections)}
  end

  defp assemble_chunk_packet(state) do
    {data, written_mask} = Chunk.encode(state.chunk_resource, {true, true, 0})

    {:chunk, x, z} = state.pos
    %Server.Play.MapChunk{
      x: x,
      z: z,
      ground_up: true,
      bit_map: written_mask,
      # We convert the chunk data to a binary so that we prevent the entire iolist being
      # sent by message. This will make a large binary, which will only be sent by reference.
      chunk_data: IO.iodata_to_binary(data),
    }
  end

  def handle_cast({:send_chunk, conn}, state) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(conn, assemble_chunk_packet(state))
    :erlang.garbage_collect(self)
    {:noreply, state}
  end
  def handle_cast(:stop_chunk, state) do
    {:stop, :normal, state}
  end
  def handle_cast({:block_destroy, {x, y, z}}, state) do
    Chunk.set_block(state.chunk_resource, {rem(x, 16), y, rem(z, 16)}, 0)

    #message = {:block, :destroy, {x, y, z}}
    message = {:world_event, :chunk, {:block_destroy, {x, y, z}}}
    McEx.Registry.world_players_send(state.world_id, message)

    {:noreply, state}
  end
  def handle_cast(:gen_chunk, state) do
    chunk = gen_chunk(state.pos)
    {:noreply, %{state | chunk_resource: chunk}}
  end
end
