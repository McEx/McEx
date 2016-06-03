defprotocol McEx.Entity.Message do

  @type t :: map
  @type entity_state :: map

  @spec broadcast_for_entity(t, entity_state) :: entity_state
  def broadcast_for_entity(message, entity_state)

end
