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
      worker(McEx.World.World, [])
    ]

    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end
end
