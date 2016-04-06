defmodule McEx.Net.Handler do
  use McProtocol.Handler
  use GenServer

  def parent_handler, do: McProtocol.Handler.Login

  def enter(%{direction: :Client, mode: :Play} = stash) do
    {:ok, handler_pid} = GenServer.start(__MODULE__, stash)
    transitions = GenServer.call(handler_pid, {:enter, stash})
    {transitions, handler_pid}
  end

  def handle(packet_data, stash, pid) do
    transitions = GenServer.call(pid, {:handle, packet_data, stash})
    {transitions, pid}
  end

  def leave(stash, pid) do
    GenServer.call(pid, {:leave, stash})
    GenServer.stop(pid)
    nil
  end

  # GenServer
  def init(_stash) do
    state =  %{
      player: nil,
      entity_id: nil,
    }
    {:ok, state}
  end

  def handle_call({:enter, stash}, _from, state) do
    {transitions, state} = McEx.Net.HandlerClauses.join(stash, state)
    {:reply, transitions, state}
  end

  def handle_call({:handle, packet_data, stash}, _from,  state) do
    packet_data = packet_data |> McProtocol.Packet.In.fetch_packet
    {transitions, state} = McEx.Net.HandlerClauses.handle_packet(
      packet_data.packet, stash, state)
    {:reply, transitions, state}
  end
end
