
defmodule McEx.Chunk.Manager do
  use GenServer
  use McEx.Util

  def start_link(params) do
    GenServer.start_link(__MODULE__, params, [])
  end

  def get_chunk(manager, chunk) do
    GenServer.call(manager, {:get_chunk, chunk})
  end

  def lock_chunk(manager, chunk, process) do
    GenServer.cast(manager, {:lock_chunk, chunk, process})
  end
  def release_chunk(manager, chunk, process) do
    GenServer.cast(manager, {:release_chunk, chunk, process})
  end

  defmodule ChunkData do
    defstruct pid: nil, locks: HashSet.new
  end

  def init(world_id) do
    :gproc.reg({:n, :l, {:world_chunk_manager, world_id}})
    {:ok, %{
        world_id: world_id,
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
