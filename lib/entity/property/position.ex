defmodule McEx.Entity.Property.Position do
  use McEx.Entity.Property

  @moduledoc """
  This property provides a common interface for storing the position of an event.
  It should probably be used in all entities that can move around, as other
  properties depend on it.

  It provides a public API which is usable by other properties.
  """

  defp calc_delta_pos({x, y, z}, {x0, y0, z0}),
  do: {:rel_pos, x0-x, y0-y, z0-z}

  def initial(_args, state) do
    prop = %{
      pos: {0, 100, 0},
      look: {0, 0},
      on_ground: false,
      initial: true,
    }
    set_prop(state, prop)
  end

  # Public API

  @doc """
  Part of the public api.

  This will get the full current position state of the entity.
  """
  def get_position(state) do
    get_prop(state)
  end

  @doc """
  Part of the public api.

  This will UPDATE the position state for the entity.
  Missing items will not be updated.
  """
  def set_position(state, update) do
    prop = get_prop(state)

    pos = Map.get(update, :pos, prop.pos)
    look = Map.get(update, :look, prop.look)
    on_ground = Map.get(update, :on_ground, prop.on_ground)

    new_prop = %{prop |
             pos: pos,
             look: look,
             on_ground: on_ground,
             initial: false,
            }
    state = set_prop(state, new_prop)

    if prop != new_prop do
      state = McEx.Entity.Message.Move.new(state, prop.pos, pos, look, on_ground)
      |> broadcast(state)
    end

    state
  end

end
