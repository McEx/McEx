defmodule McEx.Net.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      supervisor(McEx.Net.ConnectionSupervisor,
                 [[name: McEx.Net.ConnectionSupervisor]]),
      worker(Task, [fn -> McEx.Net.Listener.accept(25565) end]),
    ]

    options = [strategy: :one_for_one]

    supervise(children, options)
  end

end
