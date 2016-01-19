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

  def start_link(name) do
    GenServer.start_link(__MODULE__, {name})
  end

  def get_chunk_manager(world) do
    GenServer.call(world, :get_chunk_manager)
  end

  def player_join(world_id) do
    true = Enum.member?(:gproc.lookup_pids({:p, :l, :server_player}), self())
    false = Enum.member?(:gproc.lookup_pids({:p, :l, {:world_player, world_id}}), self())
    # TODO: verify world excistence
    :gproc.reg({:p, :l, {:world_player, world_id}})
  end

  def player_leave(world_id) do
    :gproc.unreg({:p, :l, {:world_player, world_id}})
  end

  # Server
  use GenServer

  def init({name}) do
    {:ok, pid} = McEx.Chunk.Manager.start_link({name})
    :gproc.reg({:n, :l, {:world, name}})
    {:ok, %{
        players: [],
        chunk_manager: pid, 
        name: name}}
  end

  def handle_call(:get_chunk_manager, _from, state) do
    {:reply, state.chunk_manager, state}
  end
end
