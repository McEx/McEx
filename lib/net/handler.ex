defmodule McEx.Net.Handler do
  use McProtocol.Handler
  use GenServer
  require Logger

  def enter(_args, %{direction: :Client, mode: :Play} = stash) do
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

    McEx.Player.client_packet(state.player, packet_data.packet)

    unless [
        McProtocol.Packet.Client.Play.Settings,
        McProtocol.Packet.Client.Play.CustomPayload,
        McProtocol.Packet.Client.Play.TeleportConfirm,
        McProtocol.Packet.Client.Play.KeepAlive,
        McProtocol.Packet.Client.Play.PositionLook,
        McProtocol.Packet.Client.Play.Position,
        McProtocol.Packet.Client.Play.Look,
        McProtocol.Packet.Client.Play.Abilities,
      ] |> Enum.member?(packet_data.module),
    do: Logger.debug inspect packet_data

    {transitions, state} = McEx.Net.HandlerClauses.handle_packet(
      packet_data.packet, stash, state)
    {:reply, transitions, state}
  end
end
