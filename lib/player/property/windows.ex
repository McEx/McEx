defmodule McEx.Player.Property.Windows do
  use McEx.Player.Property

  alias McProtocol.Packet.{Client, Server}

  @client_status_open_inv_id 2

  def initial(state) do
    state
  end

  # Sends:
  # Server.Play.Transaction
  # Server.Play.CloseWindow
  # Server.Play.OpenWindow
  # Server.Play.WindowItems
  # Server.Play.WindowProperty
  # Server.Play.SetSlot

  # === Client packet handlers ===

  # Open player inventory
  def handle_client_packet(%Client.Play.ClientCommand{
            action_id: @client_status_open_inv_id}, state) do
    state
  end
  # Close player inventory
  def handle_client_packet(%Client.Play.CloseWindow{window_id: 0}, state) do
    state
  end

  # Apology transaction packet
  def handle_client_packet(%Client.Play.Transaction{} = packet, state) do
    state
  end

  # Enchantment window enchant click
  def handle_client_packet(%Client.Play.EnchantItem{} = packet, state) do
    state
  end

  # Window click
  def handle_client_packet(%Client.Play.WindowClick{} = packet, state) do
    state
  end

  def handle_client_packet(%Client.Play.SetCreativeSlot{} = msg, state) do
    state
  end

  # Close window
  def handle_client_packet(%Client.Play.CloseWindow{} = packet, state) do
    state
  end

end
