defmodule McEx.Chunk do
  use GenServer
  alias McEx.Net.Connection.Write
  alias McChunk.Chunk
  alias McProtocol.Packet.Server
  alias McEx.Util.Math

  # Client

  def start_link(world_id, pos, opts \\ []) do
    GenServer.start_link(__MODULE__, {world_id, pos}, opts)
  end

  def send_chunk(server, writer) do
    GenServer.cast(server, {:send_chunk, writer})
  end
  def stop_chunk(server) do
    GenServer.cast(server, :stop_chunk)
  end

  def set_block(world_id, pos, block) do
    chunk_pos = pos_to_chunk(pos)
    pid = McEx.Registry.chunk_server_pid(world_id, chunk_pos)
    GenServer.call(pid, {:set_block, pos, block})
  end

  # Server

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

  defp assemble_chunk_packet(state) do
    {data, written_mask} = Chunk.encode(state.chunk_resource, {true, true, 0})

    {:chunk, x, z} = state.pos
    %Server.Play.MapChunk{
      x: x,
      z: z,
      ground_up: true,
      bit_map: written_mask,
      # We convert the chunk data to a binary so that we prevent the entire
      # iolist being sent by message. This will make a large binary, which
      # will only be sent by reference.
      chunk_data: IO.iodata_to_binary(data),
    }
  end

  def handle_cast({:send_chunk, conn}, state) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(
      conn, assemble_chunk_packet(state))
    :erlang.garbage_collect(self)
    {:noreply, state}
  end

  def handle_cast(:stop_chunk, state) do
    {:stop, :normal, state}
  end

  def handle_cast(:gen_chunk, state) do
    {gen_module, gen_opts} = McEx.World.ConfigServer.get_key(
      state.world_id, :world_generator)
    chunk = apply(gen_module, :generate, [state.pos, gen_opts])
    {:noreply, %{state | chunk_resource: chunk}}
  end

  def handle_call({:set_block, pos, block}, _from, state) do
    Chunk.set_block(state.chunk_resource, pos_to_chunk_pos(pos), block)

    message = {:entity_msg, :chunk_event, {state.pos, :set_block, {pos, block}}}
    McEx.Registry.chunk_listeners_send(state.world_id, state.pos, message)

    {:reply, nil, state}
  end

  def handle_call({:get_block, pos}, _from, state) do
    block = Chunk.get_block(state.chunk_resource, pos_to_chunk_pos(pos))
    {:reply, block, state}
  end

  def terminate(reason, _state) do
    :gproc.goodbye
    reason
  end

  def pos_to_chunk_pos({x, y, z}) do
    {Math.mod_divisor(x, 16), y, Math.mod_divisor(z, 16)}
  end

  def pos_to_chunk({x, _, z}) do
    {:chunk, trunc(Float.floor(x / 16)), trunc(Float.floor(z / 16))}
  end
end
