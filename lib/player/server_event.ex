defmodule McEx.Player.ServerEvent do
  alias McProtocol.Packet
  use McEx.Util

  def write_packet(state, struct) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(state.connection, struct)
    state
  end

  def deg_to_byte(deg), do: round(deg / 360 * 256)

  def handle(:m, {:action_chat, message}, state) do
    IO.inspect {:chat, message}
    state
  end

  #def delta_pos_to_short({:rel_pos, dx, dy, dz}), do: {:rel_pos_short, round(dx*32), round(dy*32), round(dz*32)}

  #def handle(:m, {:entity_move, eid, _pos, rel_pos, on_ground}, state) do
  #  if eid != state.eid do
  #    {:rel_pos_short, dx, dy, dz} = delta_pos_to_short(rel_pos)
  #    write_packet(state, %Packet.Server.Play.EntityMove{
  #      entity_id: eid,
  #      d_x: dx,
  #      d_y: dy,
  #      d_z: dz,
  #      on_ground: on_ground,
  #    })
  #  end
  #  state
  #end
  #def handle(:m, {:entity_move_look, eid, _pos, rel_pos, {:look, yaw, pitch}, on_ground}, state) do
  #  if eid != state.eid do
  #    {:rel_pos_short, dx, dy, dz} = delta_pos_to_short(rel_pos)
  #    write_packet(state, %Packet.Server.Play.EntityMoveLook{
  #      entity_id: eid,
  #      d_x: dx,
  #      d_y: dy,
  #      d_z: dz,
  #      yaw: deg_to_byte(yaw),
  #      pitch: deg_to_byte(pitch),
  #      on_ground: on_ground,
  #    })
  #    write_packet(state, %Packet.Server.Play.EntityHeadRotation{
  #      entity_id: eid,
  #      head_yaw: deg_to_byte(yaw),
  #    })
  #  end
  #  state
  #end
  #def handle(:m, {:entity_look, eid, {:look, yaw, pitch}, on_ground}, state) do
  #  if eid != state.eid do
  #    write_packet(state, %Packet.Server.Play.EntityLook{
  #      entity_id: eid,
  #      yaw: deg_to_byte(yaw),
  #      pitch: deg_to_byte(pitch),
  #      on_ground: on_ground,
  #    })
  #    write_packet(state, %Packet.Server.Play.EntityHeadRotation{
  #      entity_id: eid,
  #      head_yaw: deg_to_byte(yaw),
  #    })
  #  end
  #  state
  #end

  @doc "Other part in Player.ClientEvent.handle({:keep_alive"
  def handle(:m, {:keep_alive_send, nonce, max_skipped}, state) do
    case state.keepalive_state do
      nil ->
        write_packet(state, %Packet.Server.Play.KeepAlive{keep_alive_id: nonce})
        state = put_in(state.keepalive_state, {nonce, 0})
        state
      {sent_nonce, skipped} ->
        if skipped > max_skipped do
          write_packet(state, %Packet.Server.Play.KickDisconnect{reason: %{text: "Timeout"}})
          {:stop, :timeout, state}
        else
          put_in(state.keepalive_state, {sent_nonce, skipped + 1})
        end
    end
  end

  def handle(:m, {:kick, reason}, state) do
    write_packet(state, %Packet.Server.Play.KickDisconnect{reason: %{text: reason}})
    state
  end

  def handle(:m, {:TEMP_set_crouch, eid, status}, state) do
    write_packet(state, %Packet.Server.Play.EntityMetadata{
      entity_id: eid,
      metadata: [{0, :byte, 0b10}]})
    state
  end

  def handle(:m, {:player_list, action, players}, state) do
    :ok = handle_player_list(action, players, state)
    state
  end
  def handle_player_list(:join, players, state) do
    players_add = for player <- players do
      %{
        uuid: player.uuid,
        name: player.name,
        properties: [],
        gamemode: player.gamemode,
        ping: player.ping,
        has_display_name: false,
        display_name: nil
      }
    end
    write_packet(state, %Packet.Server.Play.PlayerInfo{
      action: 0,
      #element_num: Enum.count(players_add),
      data: players_add
    })
    for player <- players do
      if player.player_pid != self do
        write_packet(state, %Packet.Server.Play.NamedEntitySpawn{
          entity_id: player.eid,
          player_uuid: player.uuid,
          x: 0, y: 260, z: 0,
          yaw: 0, pitch: 0,
          # TODO: Fix metadata
          metadata: [],
        })
      end
    end
    :ok
  end
  def handle_player_list(:leave, players, state) do
    player_leave = for player <- players do
      %{uuid: player.uuid}
    end
    write_packet(state, %Packet.Server.Play.PlayerInfo{
      action: 4,
      #element_num: Enum.count(player_leave),
      data: player_leave
    })
    :ok
  end

end
