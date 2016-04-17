defmodule McEx.Player.Property.Inventory.Player do
  import McEx.Player.Property.Inventory.Util

  def new, do: %{
    crafting: (for _ <- 0..4, do: empty_slot),
  }

  def get_slots(prop) do
    crafting = (for _ <- 0..4, do: empty_slot)
    crafting ++ prop.armor ++ prop.storage ++ prop.hotbar ++ [prop.off_hand]
  end

  def set_slot(prop, slot, slot_nr) do
    # TODO this can update state all over the place
    prop
  end

end
