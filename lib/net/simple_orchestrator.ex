defmodule McEx.Net.SimpleOrchestrator do

  use McProtocol.Orchestrator.Server

  def init(connection_pid) do
    {:ok, %{connection: connection_pid}}
  end

  def handle_next(:connect, _, state) do
    {McProtocol.Handler.Handshake, %{}, state}
  end
  def handle_next(McProtocol.Handler.Handshake, :Status, state) do
    # TODO: get actual (max) nr of players
    args = %{response: McEx.ServerListResponse.build(123, 42)}
    {McProtocol.Handler.Status, args, state}
  end
  def handle_next(McProtocol.Handler.Handshake, :Login, state) do
    {McProtocol.Handler.Login, %{}, state}
  end
  def handle_next(McProtocol.Handler.Login, _, state) do
    {McEx.Net.Handler, %{}, state}
  end

end
