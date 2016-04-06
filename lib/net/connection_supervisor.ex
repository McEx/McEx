defmodule McEx.Net.ConnectionSupervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def serve_socket(supervisor, socket) do
    Supervisor.start_child(supervisor, [socket, :Client, McEx.Net.Handler])
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
