defmodule McEx.Player.ServerEvent do
  alias McProtocol.Packet
  use McEx.Util

  def write_packet(state, struct) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(state.connection, struct)
    state
  end

  def handle(:m, {:action_chat, message}, state) do
    IO.inspect {:chat, message}
    state
  end

  def handle(:m, {:kick, reason}, state) do
    write_packet(state, %Packet.Server.Play.KickDisconnect{reason: %{text: reason}})
    state
  end

  def handle(:m, {:TEMP_set_crouch, eid, status}, state) do
    write_packet(state, %Packet.Server.Play.EntityMetadata{
      entity_id: eid,
      metadata: [{0, :byte, 0b10}]})
    state
  end

end
