defmodule McEx.Player.Property.Spawn do
  use McEx.Entity.Property

  def initial(state) do
    state
  end

  def handle_prop_collect(:collect_spawn_data, _, state) do
    pos = McEx.Entity.Property.Position.get_position(state)
    response = %{
      type: :player,
      eid: state.eid,
      uuid: state.identity.uuid,
      position: pos,
      metadata: [],
    }
    {response, state}
  end

end
