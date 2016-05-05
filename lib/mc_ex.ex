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
    config = %{
      world_id: :test_world,
      world_generator: {McEx.World.Chunk.Generator.SimpleFlatworld, nil},
    }

    children = [
      worker(McProtocol.Crypto.ServerKeyProvider, [[name: McEx.ServerKeyProvider]]),
      supervisor(McEx.World.Supervisor, [config]),
      supervisor(McEx.Net.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: McEx.Supervisor]
    supervise(children, opts)
  end
end

defmodule McEx.EntityIdGenerator do
  use GenServer

  def start_link(world_id) do
    GenServer.start_link(__MODULE__, world_id)
  end

  def get_id(world_id) do
    GenServer.call(McEx.Registry.world_service_pid(world_id, :entity_id_generator), :gen_id)
  end

  def init(server_id) do
    McEx.Registry.reg_world_service(server_id, :entity_id_generator)
    # Because of the handler system on the connection, the client is ALWAYS entity id
    # 0. Entity id 0 is therefore reserved, and should not be used for anything
    # globally.
    {:ok, 1}
  end

  def handle_call(:gen_id, _from, id) do
    {:reply, id, id + 1}
  end
end
