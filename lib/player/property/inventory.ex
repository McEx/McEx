defmodule McEx.Player.Property.Inventory do
  use McEx.Entity.Property

  alias McProtocol.Packet.{Client, Server}

  def initial(state) do
    state
  end

  def handle_client_packet(%Client.Play.CloseWindow{} = msg, state) do
    state
  end
  def handle_client_packet(%Client.Play.WindowClick{} = msg, state) do
    state
  end
  def handle_client_packet(%Client.Play.Transaction{} = msg, state) do
    state
  end
  def handle_client_packet(%Client.Play.SetCreativeSlot{} = msg, state) do
    state
  end
  def handle_client_packet(%Client.Play.HeldItemSlot{} = msg, state) do
    state
  end
  def handle_client_packet(%Client.Play.EnchantItem{} = msg, state) do
    state
  end

end
