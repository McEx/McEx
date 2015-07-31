defmodule McEx.Chunk.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      supervisor(McEx.Chunk.ChunkSupervisor, []),
      worker(McEx.Chunk.Manager, [])
    ]

    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end

defmodule McEx.Chunk.Manager do
  use GenServer
  use McEx.Util

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: McEx.Chunk.Manager])
  end

  def get_chunk(chunk) do
    GenServer.call(McEx.Chunk.Manager, {:get_chunk, chunk})
  end

  def lock_chunk(chunk, process) do
    GenServer.cast(McEx.Chunk.Manager, {:lock_chunk, chunk, process})
  end
  def release_chunk(chunk, process) do
    GenServer.cast(McEx.Chunk.Manager, {:release_chunk, chunk, process})
  end

  defmodule ChunkData do
    defstruct pid: nil, locks: HashSet.new
  end

  def init(:ok) do
    {:ok, %{
        chunks: %{}, #{x, y}: PID
      }}
  end

  def start_chunk(state, chunk) when ChunkPos.is_chunk(chunk) do
    {:ok, pid} = McEx.Chunk.ChunkSupervisor.start_chunk(chunk)
    put_in(state.chunks[chunk], %ChunkData{pid: pid})
  end
  def stop_chunk(state, chunk) when ChunkPos.is_chunk(chunk) do
    McEx.Chunk.stop_chunk(state.chunks[chunk].pid)
    update_in(state.chunks, &Map.delete(&1, chunk))
  end

  def ensure_chunk_started(state, chunk) when ChunkPos.is_chunk(chunk) do
    case Map.get(state.chunks, chunk) do
      nil -> start_chunk(state, chunk)
      _ -> state
    end
  end

  def stop_chunk_if_released(state, chunk) when ChunkPos.is_chunk(chunk) do
    case Map.get(state.chunks, chunk) do
      nil -> state
      chunk_data -> case Set.size(chunk_data.locks) do
        0 -> stop_chunk(state, chunk)
        _ -> state
      end
    end
  end

  def handle_info({:DOWN, _ref, :process, process, _reason}, state) do
    #TODO: Release all
    {:noreply, state}
  end

  def handle_cast({:lock_chunk, chunk, process}, state) do
    Process.monitor(process) #TODO: Remove monitors
    state = ensure_chunk_started(state, chunk)
    state = update_in(state.chunks[chunk].locks, &Set.put(&1, process))
    {:noreply, state}
  end
  def handle_cast({:release_chunk, chunk, process}, state) do
    state = update_in(state.chunks[chunk].locks, &Set.delete(&1, process))
    state = stop_chunk_if_released(state, chunk)
    {:noreply, state}
  end
  def handle_cast({:release_all_chunks, process}, state) do
    #TODO
    #new_chunks = Enum.map(state.chunks, fn {key, data} ->
    #  data = get_and_update_in(data.locks, &{&1, Set.delete(&1, process)})
    #end
    {:noreply, state}
  end
  
  def handle_call({:get_chunk, chunk}, _from, data) do
    response = case Map.fetch(data.chunks, chunk) do
      {:ok, chunk_data} -> {:ok, chunk_data.pid}
      err -> err
    end
    {:reply, response, data}
  end
end

defmodule McEx.Chunk.ChunkSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: McEx.Chunk.Supervisor])
  end

  def start_chunk(pos) do
    Supervisor.start_child(McEx.Chunk.Supervisor, [pos])
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
  alias McEx.Net.Packets.Server

  use Bitwise

  def start_link(pos, opts \\ []) do
    GenServer.start_link(__MODULE__, {pos}, opts)
  end

  def send_chunk(server, writer) do
    GenServer.cast(server, {:send_chunk, writer})
  end
  def stop_chunk(server) do
    GenServer.cast(server, :stop_chunk)
  end

  def init({pos}) do
    sc = Enum.reduce(1..256, <<>>, fn _, acc -> <<acc::binary, 17::little-2*8>> end)
    {:ok, %{
        pos: pos,
        block_data: :array.set(0, sc, :array.new(256, fixed: true, default: nil))}}
  end

  def write_empty_row(bin) do
    <<bin::binary, 0::256*16>>
  end
  def write_row_data(bin, row) do
    <<bin::binary, row::binary>>
  end

  def assemble_data(state) do
    filled_rows = :array.foldl(fn _, value, acc ->
      case value do
        nil -> acc ++ [false]
        data -> acc ++ [true]
      end
    end, [], state.block_data)
    filled_chunks = Enum.map(Enum.chunk(filled_rows, 16, 16), fn chunk -> Enum.reduce(chunk, fn a, b -> a or b end) end)
    <<bitmask::2*8>> = Enum.reduce(filled_chunks, <<>>, fn bit, acc -> 
      bit_n = if bit, do: 1, else: 0
      <<bit_n::1, acc::bitstring>> 
    end)

    block_data = :array.foldl(fn num, value, acc ->
      if Enum.fetch!(filled_chunks, num >>> 4) do
        case value do
          nil -> 
            write_empty_row(acc)
          row -> 
            write_row_data(acc, row)
        end
      else
        acc
      end
    end, <<>>, state.block_data)

    light_size = trunc(byte_size(block_data) / 4)

    chunk_data = <<
      block_data::binary, 
      0::size(light_size)-unit(8), 
      0::size(light_size)-unit(8), 
      0::size(256)-unit(8)>>

    %{pos: state.pos,
      bitmask: bitmask,
      continuous: true,
      chunk_data: chunk_data}
  end

  def write_chunk_packet(state) do
    alias McEx.DataTypes.Encode
    kit = assemble_data(state)
    {:chunk, x, z} = kit.pos
    %McEx.Net.Packets.Server.Play.ChunkData{
      chunk_x: x, 
      chunk_z: z, 
      continuous: kit.continuous, 
      section_mask: kit.bitmask, 
      chunk_data: Encode.varint(byte_size(kit.chunk_data)) <> kit.chunk_data}
  end

  def handle_cast({:send_chunk, writer}, state) do
    Write.write_packet(writer, write_chunk_packet(state))
    {:noreply, state}
  end
  def handle_cast(:stop_chunk, state) do
    {:stop, :normal, state}
  end
end
