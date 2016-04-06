defmodule McEx.Net.Listener do
  require Logger

  @tcp_listen_options [:binary, packet: :raw, active: false, reuseaddr: true]

  def accept(port) do
    {:ok, listen} = :gen_tcp.listen(port, @tcp_listen_options)
    Logger.info("Listening on port #{port}")
    accept_loop(listen)
  end

  defp accept_loop(listen) do
    {:ok, socket} = :gen_tcp.accept(listen)
    {:ok, pid} = McEx.Net.ConnectionSupervisor.serve_socket(
      McEx.Net.ConnectionSupervisor, socket)
    :ok = :gen_tcp.controlling_process(socket, pid)
    accept_loop(listen)
  end

end
