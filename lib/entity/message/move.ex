defmodule McEx.Entity.Message.Move do

  defstruct [:world, :entity_id, :pos, :delta_pos, :look, :on_ground]

  defp calc_delta_pos({x, y, z}, {x0, y0, z0}),
  do: {:rel_pos, x0-x, y0-y, z0-z}

  def new(state, old_pos, pos, look, on_ground) do
    %__MODULE__{
      world: state.world_id,
      entity_id: state.eid,
      pos: pos,
      delta_pos: calc_delta_pos(old_pos, pos),
      look: look,
      on_ground: on_ground,
    }
  end

end

defimpl McEx.Entity.Message, for: McEx.Entity.Message.Move do

  def broadcast_for_entity(message, entity_state) do
    entity_state = McEx.Entity.Property.prop_broadcast(entity_state, message)
    McEx.Entity.Property.Shards.broadcast_shard(entity_state, :broadcast, message)
  end

end
