defmodule McEx.Player.Property.Inventory.Util do
  alias McProtocol.Acceptor.ProtocolState.Connection

  def send_client(state, packet), do: Connection.write_packet(state.connection, packet)

  def empty_slot, do: %McProtocol.DataTypes.Slot{id: -1}

end
