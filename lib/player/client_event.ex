defmodule McEx.Player.ClientEvent do
  def bcast_players(world_id, msg) do
    McEx.Registry.world_players_send(world_id, msg)
  end
  def bcast_players_sev(world_id, msg) do
    bcast_players(world_id, {:server_event, msg})
  end

  def handle({:action_digging, mode, {x, _, z} = position, face}, state) do
    if mode == :finished do
      chunk_pos = {:chunk, round(Float.floor(x / 16)), round(Float.floor(z / 16))}

      chunk_pid = McEx.Registry.chunk_server_pid(state.world_id, chunk_pos)
      GenServer.cast(chunk_pid, {:block_destroy, position})
    end
    state
  end

  def handle({:action_punch_animation}, state) do
    state
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
