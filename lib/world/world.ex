defmodule McEx.World.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      supervisor(McEx.Chunk.ChunkSupervisor, []),
      supervisor(McEx.World.WorldSupervisor, []),
      worker(McEx.World.Manager, [])
    ]

    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end

defmodule McEx.World.WorldSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_world(name) do
    Supervisor.start_child(__MODULE__, [name])
  end

  def init(:ok) do
    children = [
      worker(McEx.World, [])
    ]

    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end
end

defmodule McEx.World.Manager do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def get_world(name) do
    GenServer.call(__MODULE__, {:get_world, name})
  end

  def init(:ok) do
    {state, pid} = start_world(%{worlds: %{}}, :test)
    {:ok, state}
  end

  defp world_running?(state, name) do
    state.worlds[name] !== nil
  end

  defp start_world(state, name) do
    {:ok, pid} = McEx.World.WorldSupervisor.start_world(name)
    {put_in(state.worlds[name], pid), pid}
  end

  def handle_call({:get_world, :test}, _from, state) do
    {:reply, state.worlds.test, state}
  end
end

defmodule McEx.World do
  # Client

  def start_link(world_id) do
    GenServer.start_link(__MODULE__, world_id)
  end

  def get_chunk_manager(world) do
    GenServer.call(world, :get_chunk_manager)
  end


  # Server
  use GenServer

  def init(world_id) do
    {:ok, pid} = McEx.Chunk.Manager.start_link(world_id)
    {:ok, _} = McEx.World.PlayerTracker.start_link(world_id)
    :gproc.reg({:n, :l, {:world, world_id}})
    {:ok, %{
        players: [],
        chunk_manager: pid, 
        world_id: world_id}}
  end

  def handle_call(:get_chunk_manager, _from, state) do
    {:reply, state.chunk_manager, state}
  end
end

defmodule McEx.World.PlayerTracker do

  defmodule PlayerListRecord do
    defstruct eid: nil, player_pid: nil, mon_ref: nil, uuid: nil, name: nil, gamemode: 0, ping: 0, display_name: nil
  end

  # Client
  def start_link(world_id) do
    GenServer.start_link(__MODULE__, world_id)
  end

  def for_world(world_id) do
    :gproc.lookup_pid({:n, :l, {:world, world_id, :player_tracker}})
  end

  def player_join(world_id, %PlayerListRecord{} = record) do
    GenServer.call(for_world(world_id), {:player_join, %{record | player_pid: self}})
    :gproc.reg({:p, :l, {:world, world_id, :players}})
  end

  def player_leave(world_id) do
    :gproc.unreg({:p, :l, {:world, world_id, :players}})
    GenServer.call(for_world(world_id), {:player_leave, self})
  end

  # Server
  use GenServer

  def init(world_id) do
    :gproc.reg({:n, :l, {:world, world_id, :player_tracker}})
    {:ok, %{
        world_id: world_id,
        players: []
      }}
  end
  
  def handle_call({:player_join, %PlayerListRecord{} = record}, _from, state) do
    state = handle_join(record, state)
    {:reply, state.players, state}
  end
  def handle_call({:player_leave, player_pid}, _from, state) do
    state = handle_leave(player_pid, state)
    {:reply, nil, state}
  end

  def handle_info({:DOWN, mon_ref, type, object, info}, state) do
    player_pid = Enum.find(state.players, fn(rec) -> rec.mon_ref == mon_ref end).player_pid
    state = handle_leave(player_pid, state)
    {:noreply, state}
  end

  def handle_join(%PlayerListRecord{} = record, state) do
    mon_ref = :erlang.monitor(:process, record.player_pid)
    record = %{record | mon_ref: mon_ref}
    :gproc.send({:p, :l, {:world, state.world_id, :players}}, {:server_event, {:player_list, :join, [record]}})
    state = update_in state.players, &([record | &1])
    send(record.player_pid, {:server_event, {:player_list, :join, state.players}})
    state
  end
  def handle_leave(pid, state) do
    record = Enum.find(state.players, fn(rec) -> rec.player_pid == pid end)
    :erlang.demonitor(record.mon_ref)
    :gproc.send({:p, :l, {:world, state.world_id, :players}}, {:server_event, {:player_list, :leave, [record]}})
    update_in state.players, &(Enum.filter(&1, fn(rec) -> rec != record end))
  end
end
