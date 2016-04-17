defmodule McEx.Player.ClientEvent do
  def bcast_players(world_id, msg) do
    McEx.Registry.world_players_send(world_id, msg)
  end
  def bcast_players_sev(world_id, msg) do
    bcast_players(world_id, {:server_event, msg})
  end

  def handle({:player_set_crouch, status}, state) do
    bcast_players_sev(state.world_id, {:TEMP_set_crouch, state.eid, status})
    state
  end

  def handle(event, state) do
    IO.inspect event
    state
  end
end
