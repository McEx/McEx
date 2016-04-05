
defmodule McEx.Chunk.ChunkSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: McEx.Chunk.Supervisor])
  end

  def start_chunk(world_id, pos) do
    Supervisor.start_child(McEx.Chunk.Supervisor, [world_id, pos])
  end

  def init(:ok) do
    children = [
      worker(McEx.Chunk, [], restart: :transient)
    ]

    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end
end

defmodule McEx.Chunk do
  use GenServer
  alias McEx.Net.Connection.Write
  alias McProtocol.Packet.Server

  use Bitwise

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
    chunk = McEx.Native.Chunk.create
    {:chunk, x, z} = pos
    McEx.Topic.reg_world_chunk(world_id, pos)
    McEx.Native.Chunk.generate_chunk(chunk, {x, z})
    {:ok, %{
        world_id: world_id,
        chunk_resource: chunk,
        pos: pos}}
  end

  def write_empty_row(bin) do
    <<bin::binary, 0::256*16>>
  end
  def write_row_data(bin, row) do
    <<bin::binary, row::binary>>
  end

  def write_chunk_packet(state) do
    alias McProtocol.DataTypes.Encode

    {written_mask, size, data} = McEx.Native.Chunk.assemble_packet(state.chunk_resource,
                                                                   {true, true, 0})

    {:chunk, x, z} = state.pos
    %Server.Play.MapChunk{
      x: x,
      z: z,
      ground_up: true,
      bit_map: written_mask,
      chunk_data: data,
    }
  end

  def handle_cast({:send_chunk, conn}, state) do
    #Write.write_packet(writer, write_chunk_packet(state))
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(conn, write_chunk_packet(state))
    {:noreply, state}
  end
  def handle_cast(:stop_chunk, state) do
    {:stop, :normal, state}
  end
  def handle_cast({:block_destroy, {x, y, z}}, state) do
    McEx.Native.Chunk.destroy_block(state.chunk_resource, {rem(x, 16), y, rem(z, 16)})

    message = {:block, :destroy, {x, y, z}}
    McEx.Topic.send_world_player(state.world_id, message)

    {:noreply, state}
  end
end
