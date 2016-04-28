defmodule McEx.Player.Property.Inventory do
  use McEx.Player.Property

  alias McProtocol.Packet.{Client, Server}
  alias McProtocol.DataTypes.Slot

  @special_slots [:head, :torso, :legs, :shoes, :offhand]

  def initial(state) do
    prop = %{
      held_slot: 0,
      main: :array.new(size: 9*4, fixed: true, default: %Slot{}),
      special: @special_slots |> Enum.map(&({&1, %Slot{}})) |> Enum.into(%{}),
    }
    state = set_prop(state, prop)

    set_slot(state, 0, %Slot{id: 1, count: 5})
  end

  def handle_client_packet(%Client.Play.HeldItemSlot{} = msg, state) do
    prop = %{get_prop(state) | held_slot: msg.slot}
    set_prop(state, prop)
  end

  # Public API

  def set_slot(state, slot_id, %Slot{} = content) when is_number(slot_id) do
    prop = get_prop(state)
    main = :array.set(slot_id, content, prop.main)
    set_prop(state, %{prop | main: main})
  end
  def set_slot(state, slot_id, %Slot{} = content) when is_atom(slot_id) do
    prop = get_prop(state)
    special = %{state.special | slot_id => content}
    set_prop(state, %{prop | special: special})
  end

  def get_slot(state, slot_id) when is_number(slot_id) do
    :array.get(slot_id, get_prop(state).main)
  end
  def get_slot(state, slot_id) when is_atom(slot_id) do
    Map.fetch!(get_prop(state).special, slot_id)
  end

end
