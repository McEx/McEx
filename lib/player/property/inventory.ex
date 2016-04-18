defmodule McEx.Player.Property.Inventory do
  use McEx.Entity.Property
  require Logger

  alias McProtocol.Packet.{Client, Server}
  import __MODULE__.Util

  def initial(state) do
    prop = %{
      window: __MODULE__.Player,
      window_state: __MODULE__.Player.new,
      window_id: 0,
      armor: (for _ <- 5..8, do: empty_slot),
      storage: (for _ <- 9..35, do: empty_slot),
      hotbar: (for _ <- 36..44, do: empty_slot),
      off_hand: empty_slot,
      cursor: empty_slot,
      hotbar_selection: 0,
    }

    send_inventory_reset(state, prop)

    prop
  end

  def handle_client_packet(%Client.Play.CloseWindow{} = msg, state) do
    state
  end

  def handle_client_packet(%Client.Play.WindowClick{} = msg, state) do
    # TODO testing
    Logger.debug inspect msg
    n = msg.slot
    write_client_packet(state, %Server.Play.Chat{message: ~s({"text": "Hi! #{n}"}), position: 2})
    state = set_slot(state, %McProtocol.DataTypes.Slot{id: 1, count: n, damage: 0}, n)

    # TODO: notify other players if visible item changed

    state
  end

  def handle_client_packet(%Client.Play.Transaction{} = msg, state) do
    state
  end

  def handle_client_packet(%Client.Play.SetCreativeSlot{} = msg, state) do
    state
  end

  def handle_client_packet(%Client.Play.HeldItemSlot{slot_id: slot_id} = msg, state) when 0 <= slot_id and slot_id < 9 do
    prop = %{get_prop(state) | hotbar_selection: msg.slot_id}
    # TODO: notify other players

    set_prop(state, prop)
  end

  def handle_client_packet(%Client.Play.EnchantItem{} = msg, state) do
    state
  end

  def handle_entity_event({:interact, entity}, state) do
    # maybe open a new window
    state
  end

  defp set_slot(state, slot, slot_nr) do
    prop = get_prop(state)

    prop = prop.window.set_slot(prop, slot, slot_nr)

    write_client_packet(state, %Server.Play.SetSlot{
      window_id: prop.window_id,
      slot: slot_nr,
      item: slot,
    })

    set_prop(state, prop)
  end

  defp open_inventory(state) do
    prop = get_prop(state)

    # close old
    # open new
    send_inventory_reset(state, prop)

    set_prop(state, prop)
  end

  defp send_inventory_reset(state, prop) do
    slots = prop.window.get_slots(prop)

    write_client_packet(state, %Server.Play.WindowItems{
      window_id: prop.window_id,
      items: slots,
    })

    # the same slots, once again
    slots
    |> Enum.with_index
    |> Enum.map(fn {slot, slot_nr} ->
      write_client_packet(state, %Server.Play.SetSlot{
        window_id: prop.window_id,
        slot: slot_nr,
        item: slot,
      })
    end)

    # cursor
    write_client_packet(state, %Server.Play.SetSlot{
      window_id: -1,
      slot: -1,
      item: prop.cursor,
    })
  end

end
