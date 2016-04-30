defmodule McEx.Entity.Property.Spawn do
  use McEx.Entity.Property

  def initial(args, state) do
    set_prop(state, args)
  end

  def handle_prop_collect(:collect_spawn_data, _, state) do
    prop = get_prop(state)
    pos = McEx.Entity.Property.Position.get_position(state)
    response = %{
      type: prop.type,
      entity_type_id: prop[:entity_type_id],
      eid: state.eid,
      uuid: prop.uuid,
      position: pos,
      metadata: [],
    }
    {response, state}
  end

end
