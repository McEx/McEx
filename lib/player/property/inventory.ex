defmodule McEx.Player.Property.Inventory do
  use McEx.Player.Property

  alias McProtocol.Packet.{Client, Server}
  alias McProtocol.DataTypes.Slot

  def slot_type(id) when id >= 0 and id <= 4, do: :transient
  def slot_type(id) when id >= 5 and id <= 8, do: :special
  def slot_type(id) when id >= 9 and id <= 44, do: :main
  def slot_type(id) when id == 45, do: :special

  def initial(_args, state) do
    prop = %{
      action: 0,
      held_slot: 0,
      slots: :array.new(size: 46, fixed: true, default: nil)
    }
    state = set_prop(state, prop)

    set_slot(state, 36, %Slot{id: 1, count: 5})
  end

  def handle_client_packet(%Client.Play.HeldItemSlot{} = msg, state) do
    prop = %{get_prop(state) | held_slot: msg.slot}
    set_prop(state, prop)
  end

  # Window interaction

  # Window click
  def handle_client_packet(%Client.Play.WindowClick{} = packet, state) do
    if McEx.Player.Property.Windows.current_active_window(state) == {nil, nil} do
      handle_inventory_click(packet, state)
    else
      state
    end
  end

  def handle_client_packet(%Client.Play.BlockDig{status: 4}, state) do
    McEx.World.EntitySupervisor.start_entity(
      state.world_id, McEx.Entity.Item, %{})
    state
  end

  # When not handling a case, disapprove.
  def handle_inventory_click(packet, state) do
    IO.inspect packet
    %Server.Play.Transaction{
      window_id: 0,
      action: packet.action,
      accepted: false}
    |> write_client_packet(state)

    state
    |> send_inventory
  end

  defp send_slot(state, window_id, slot_id, item) do
    %Server.Play.SetSlot{
      window_id: window_id,
      slot: slot_id,
      item: item}
    |> write_client_packet(state)
  end

  # Public API

  def set_slot(state, slot_id, %Slot{} = content) when is_number(slot_id) do
    prop = get_prop(state)
    slots = :array.set(slot_id, content, prop.slots)
    send_slot(state, 0, slot_id, content)
    set_prop(state, %{prop | slots: slots})
  end

  def get_slot(state, slot_id) when is_number(slot_id) do
    :array.get(slot_id, get_prop(state).slots)
  end

  def send_inventory(state) do
    prop = get_prop(state)
    inv_items = :array.to_list(prop.slots)
    %Server.Play.WindowItems{
      window_id: 0,
      items: inv_items}
    |> write_client_packet(state)
    %Server.Play.SetSlot{
      window_id: -1,
      slot: -1,
      item: nil}
    |> write_client_packet(state)
    state
  end

end
