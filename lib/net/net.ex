defmodule McEx.Net do
  use Supervisor
  require Logger

  alias McEx.Net.ConnectionManager

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(McEx.Net.Crypto.KeyServer, [[name: McEx.Net.Crypto.KeyServer]]),
      supervisor(McEx.Net.Connection.Supervisor, [[name: McEx.Net.Connection.Supervisor]]),
      worker(ConnectionManager, [[name: ConnectionManager]]),
      worker(Task, [McEx.Net, :accept, [25565]])
    ]

    opts = [strategy: :one_for_one, name: McEx.Net]
    supervise(children, opts)
  end

  def accept(port) do
    {:ok, listen} = :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])
    Logger.info("Listening on port #{port}")
    accept_loop(listen)
  end

  defp accept_loop(listen) do
    {:ok, client} = :gen_tcp.accept(listen)
    {:ok, pid} = ConnectionManager.serve(ConnectionManager, client)
    :ok = :gen_tcp.controlling_process(client, pid)
    accept_loop(listen)
  end
end

defmodule McEx.Net.ConnectionManager do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def serve(server, socket) do
    GenServer.call(server, {:serve, socket})
  end

  def init(:ok) do
    {:ok, []}
  end

  def handle_call({:serve, socket}, _from, connections) do
    {:ok, pid} = McEx.Net.Connection.Supervisor.serve_socket(McEx.Net.Connection.Supervisor, socket)
    {:reply, {:ok, pid}, connections ++ [pid]}
  end
end
