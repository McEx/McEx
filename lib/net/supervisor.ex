defmodule McEx.Net.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      supervisor(McEx.Net.ConnectionSupervisor,
                 [[name: McEx.Net.ConnectionSupervisor]]),
      worker(Task, [fn -> acceptor end])
    ]

    options = [strategy: :one_for_one]

    supervise(children, options)
  end

  def acceptor do
    McProtocol.Acceptor.SimpleAcceptor.accept(
      25565,
      fn socket ->
        McEx.Net.ConnectionSupervisor.serve_socket(
          McEx.Net.ConnectionSupervisor, socket)
      end,
      fn pid, _socket ->
        McProtocol.Connection.Manager.start_reading(pid)
      end
    )
  end

end
