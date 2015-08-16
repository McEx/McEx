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
      worker(McEx.EntityIdGenerator, [[name: @entity_id_gen_name]]),
      supervisor(McEx.World.Supervisor, []),
      supervisor(McEx.Player.Supervisor, []),
      supervisor(McEx.Net, [])
    ]

    opts = [strategy: :one_for_one, name: McEx.Supervisor]
    supervise(children, opts)
  end
end

defmodule McEx.EntityIdGenerator do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get_id do
    GenServer.call(McEx.EntityIdGenerator, :gen_id)
  end

  def init(:ok) do
    {:ok, 1}
  end

  def handle_call(:gen_id, _from, id) do
    {:reply, id, id + 1}
  end
end
