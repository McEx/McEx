defmodule McEx.Player.ServerEvent do
  alias McProtocol.Packet
  use McEx.Util

  def write_packet(state, struct) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(state.connection, struct)
    state
  end

  def handle(:m, {:action_chat, message}, state) do
    IO.inspect {:chat, message}
    state
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
