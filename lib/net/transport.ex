defmodule McEx.Net.Connection.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def serve_socket(supervisor, socket) do
    #Supervisor.start_child(supervisor, [fn -> McEx.Net.Connection.start_serve(socket) end])
    Supervisor.start_child(supervisor, [socket, McProtocol.Handler.Login])
  end

  def init(:ok) do
    children = [
      worker(McProtocol.Acceptor.Connection, [], restart: :temporary)
    ]

    opts = [
      strategy: :simple_one_for_one,
    ]
    supervise(children, opts)
  end
end

defmodule ClosedError do
  defexception []
  def message(e) do
    "Connection closed"
  end
end
