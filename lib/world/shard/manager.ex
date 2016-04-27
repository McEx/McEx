defmodule McEx.World.Shard.Manager do
  use GenServer

  # Client

  def start_link(world_id) do
    GenServer.start_link(__MODULE__, world_id)
  end

  def get_shard_manager(world_id) do
    McEx.Registry.world_service_pid(world_id, :shard_manager)
  end

  def ensure_shard_started(world_id, pos) do
    case McEx.Registry.shard_server_pid?(world_id, pos) do
      {:ok, pid} -> pid
      :noreg -> GenServer.call(get_shard_manager(world_id), {:get_shard, pos})
    end
  end

  # Server

  def init(world_id) do
    McEx.Registry.reg_world_service(world_id, :shard_manager)
    state = %{
      world_id: world_id,
      shards: MapSet.new,
    }
    {:ok, state}
  end

  def handle_call({:get_shard, pos}, _from, state) do
    if MapSet.member?(state.shards, pos) do
      pid = McEx.Registry.shard_server_pid(state.world_id, pos)
      {:reply, pid, state}
    else
      {:ok, pid} = McEx.World.Shard.Supervisor.start_shard(state.world_id, pos)
      state = %{state | shards: MapSet.put(state.shards, pos)}
      {:reply, pid, state}
    end
  end

end
