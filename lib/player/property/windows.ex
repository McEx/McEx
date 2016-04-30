defmodule McEx.Player.Property.Windows do
  use McEx.Player.Property

  alias McProtocol.Packet.{Client, Server}

  @client_status_open_inv_id 2

  window_types = [
    {"minecraft:chest", :chest},
    {"minecraft:crafting_table", :crafting_table},
    {"minecraft:furnace", :furnace},
    {"minecraft:dispenser", :dispenser},
    {"minecraft:enchantment_table", :enchantment_table},
    {"minecraft:brewing_stand", :brewing_stand},
    {"minecraft:villager", :villager},
    {"minecraft:beacon", :beacon},
    {"minecraft:anvil", :anvil},
    {"minecraft:hopper", :hopper},
    {"minecraft:dropper", :dropper},
    # Leave EntityHorse out for now, it is paired to an entity.
  ]
  @window_atom_names window_types
  |> Enum.map(fn {name, atom} -> {atom, name} end) |> Enum.into(%{})

  def initial(_args, state) do
    prop = %{
      current_id: nil,
      current_type: nil,
      next_id: 1,
    }
    set_prop(state, prop)
  end

  # Sends:
  # Server.Play.Transaction
  # Server.Play.CloseWindow
  # Server.Play.OpenWindow
  # Server.Play.WindowItems
  # Server.Play.WindowProperty
  # Server.Play.SetSlot

  # === Client packet handlers ===

  ## Open player inventory
  #def handle_client_packet(%Client.Play.ClientCommand{
  #          action_id: @client_status_open_inv_id}, state) do
  #  state
  #end
  ## Close player inventory
  #def handle_client_packet(%Client.Play.CloseWindow{window_id: 0}, state) do
  #  state
  #end

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
    prop = get_prop(state)
    if prop.current_id == packet.window_id do
      prop = %{
        prop |
        current_id: nil,
        current_type: nil,
      }
      set_prop(state, prop)
    else
      state
    end
  end

  # Public API

  def open_window(type, title, slot_count, state) do
    state = if get_prop(state).current_id != nil do
      close_window(get_prop(state).current_id, state)
    else
      state
    end

    prop = get_prop(state)
    window_id = prop.next_id
    prop = %{
      prop |
      current_id: window_id,
      current_type: type,
      next_id: window_id + 1,
    }

    %Server.Play.OpenWindow{
      window_id: window_id,
      inventory_type: Map.fetch!(@window_atom_names, type),
      window_title: Poison.encode!(%{text: title}),
      slot_count: slot_count}
    |> write_client_packet(state)

    {window_id, set_prop(state, prop)}
  end

  def close_window(window_id, state) do
    prop = get_prop(state)
    if window_id == prop.current_id do
      prop = %{
        prop |
        current_id: nil,
        current_type: nil,
      }

      %Server.Play.CloseWindow{
        window_id: window_id}
      |> write_client_packet(state)

      set_prop(state, prop)
      |> prop_broadcast(:window_close, window_id)
    else
      state
    end
  end

  def current_active_window(state) do
    prop = get_prop(state)
    {prop.current_id, prop.current_type}
  end

end
