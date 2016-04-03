defmodule McEx.Player.ClientEvent do
  def bcast_players(world_id, msg) do
    :gproc.send({:p, :l, {:world, world_id, :players}}, msg)
  end
  def bcast_players_sev(world_id, msg), do: bcast_players(world_id, {:server_event, msg})

  def calc_delta_pos({:pos, x, y, z}, {:pos, x0, y0, z0}), do: {:rel_pos, x-x0, y-y0, z-z0}

  def handle({:set_pos, pos, on_ground}, state) do
    delta_pos = calc_delta_pos(pos, state.position)
    bcast_players_sev(state.world_id, {:entity_move, state.eid, pos, delta_pos, on_ground})

    %{state |
      position: pos,
      on_ground: on_ground}
    |> McEx.Player.World.load_chunks
  end

  def handle({:set_pos_look, pos, look, on_ground}, state) do
    delta_pos = calc_delta_pos(pos, state.position)
    bcast_players_sev(state.world_id, {:entity_move_look, state.eid, pos, delta_pos, look, on_ground})

    %{state |
      position: pos,
      look: look,
      on_ground: on_ground}
    |> McEx.Player.World.load_chunks
  end

  def handle({:set_look, look, on_ground}, state) do
    bcast_players_sev(state.world_id, {:entity_look, state.eid, look, on_ground})

    %{state |
      look: look,
      on_ground: on_ground}
  end

  def handle({:set_on_ground, on_ground}, state) do
    %{state |
      on_ground: on_ground}
  end

  def handle({:action_digging, mode, {x, _, z} = position, face}, state) do
    if mode == :finished do
      chunk_pos = {:chunk, round(Float.floor(x / 16)), round(Float.floor(z / 16))}
      GenServer.cast(:gproc.lookup_pid({:n, :l, {:world, state.world_id, :chunk, chunk_pos}}), {:block_destroy, position})
    end
    state
  end

  def handle({:action_punch_animation}, state) do
    state
  end

  def handle({:player_set_crouch, _, status}, state) do
    bcast_players_sev(state.world_id, {:TEMP_set_crouch, state.eid, status})
    state
  end

  @doc "Other part in Player.ServerEvent.handle_info({:server_event, {:keep_alive"
  def handle({:keep_alive, nonce}, state) do
    {sent_nonce, _} = state.keepalive_state
    if nonce == sent_nonce do
      put_in state.keepalive_state, nil
    else
      {:stop, :bad_keep_alive, state}
    end
  end

  def handle(event, state) do
    IO.inspect event
    state
  end
end
