defmodule McEx.Entity.Property.Position do
  use McEx.Entity.Property

  def calc_delta_pos({:pos, x, y, z}, {:pos, x0, y0, z0}),
  do: {:rel_pos, x-x0, y-y0, z-z0}

  def initial(state) do
    prop = %{
      pos: {:pos, 0, 100, 0},
      look: {:look, 0, 0},
      on_ground: false,
    }
    set_prop(state, prop)
  end

  def get_position(state) do
    get_prop(state)
  end

  def set_position(state, update) do
    prop = get_prop(state)

    pos = Map.get(update, :pos, prop.pos)
    delta_pos = calc_delta_pos(prop.pos, pos)
    look = Map.get(update, :look, prop.look)
    on_ground = Map.get(update, :on_ground, prop.on_ground)

    entity_broadcast(state, :move, {pos, delta_pos, look, on_ground})

    prop = %{prop |
             pos: pos,
             look: look,
             on_ground: on_ground,
            }
    set_prop(state, prop)
  end

end
