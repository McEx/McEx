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
  # Client
  def start_link(world_id) do
    GenServer.start_link(__MODULE__, world_id)
  end

  def for_world(world_id) do
    :gproc.lookup_pid({:n, :l, {:world, world_id, :player_tracker}})
  end

  def player_join(world_id) do
    true = Enum.member?(:gproc.lookup_pids({:p, :l, :server_player}), self())
    false = Enum.member?(:gproc.lookup_pids({:p, :l, {:world, world_id, :players}}), self())
    # TODO: verify world excistence
    :gproc.reg({:p, :l, {:world, world_id, :players}})
    GenServer.call(for_world(world_id), {:player_join, self()})
  end

  def player_leave(world_id) do
    :gproc.unreg({:p, :l, {:world, world_id, :players}})
    GenServer.call(for_world(world_id), {:player_leave, self()})
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
  
  def handle_call({:player_join, player_pid}, _from, state) do
    mon_ref = :erlang.monitor(:process, player_pid)
    state = Map.update_in state.players, &([{player_pid, mon_ref} | &1])
    {:reply, nil, state}
  end
  def handle_call({:player_leave, player_pid}, _from, state) do
    {_, mon_ref} = Enum.find(state.players, fn({pid, _}) -> pid == player_pid end)
    :erlang.unmonitor(mon_ref)
    {:reply, nil, state}
  end
end
