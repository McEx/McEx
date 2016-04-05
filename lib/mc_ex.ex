defmodule McEx do
  def start(_type, _args) do
    McEx.Supervisor.start_link
  end
end

defmodule McEx.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  @entity_id_gen_name McEx.EntityIdGenerator
  @net_name McEx.Net

  def init(:ok) do
    children = [
      #worker(McEx.EntityIdGenerator, [[name: @entity_id_gen_name]]),
      worker(McProtocol.Crypto.ServerKeyProvider, [[name: McEx.ServerKeyProvider]]),
      supervisor(McEx.World.Supervisor, []),
      #supervisor(McEx.Player.Supervisor, []),
      supervisor(McEx.Net, [])
    ]

    opts = [strategy: :one_for_one, name: McEx.Supervisor]
    supervise(children, opts)
  end
end

defmodule McEx.EntityIdGenerator do
  use GenServer
  # TODO: Should be removed and replaced with entity id mapping closer to connection.
  # To fully support world/server switching, we need a way for entity ids to be per-connection,
  # at least for proxies. While we do this, we might as well go all the way and use the same logic
  # for McEx, and simplify the entity system in the process.

  def start_link(world_id) do
    GenServer.start_link(__MODULE__, world_id)
  end

  def get_id(world_id) do
    GenServer.call(McEx.Registry.world_service_pid(world_id, :entity_id_generator), :gen_id)
  end

  def init(server_id) do
    McEx.Registry.reg_world_service(server_id, :entity_id_generator)
    {:ok, 1}
  end

  def handle_call(:gen_id, _from, id) do
    {:reply, id, id + 1}
  end
end
