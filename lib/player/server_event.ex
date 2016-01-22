defmodule McEx.Player.ServerEvent do
  alias McEx.Net.Connection.Write
  use McEx.Util

  def handle(:m, {:action_chat, message}, state) do
    IO.inspect {:chat, message}
    state
  end

  def handle(:m, {:set_pos, player_name, pos}, state) do
    state
  end

  @doc "Other part in Player.ClientEvent.handle({:keep_alive"
  def handle(:m, {:keep_alive_send, nonce, max_skipped}, state) do
    case state.keepalive_state do
      nil -> 
        Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.KeepAlive{nonce: nonce})
        put_in(state.keepalive_state, {nonce, 0})
      {sent_nonce, skipped} ->
        if skipped > max_skipped do
          {:stop, :timeout, state}
        else
          put_in(state.keepalive_state, {sent_nonce, skipped + 1})
        end
    end
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
        property_num: 0,
        properties: [],
        gamemode: player.gamemode,
        ping: player.ping,
        has_display_name: false,
        display_name: nil
      }
    end
    Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.PlayerListItem{
      action: 0,
      element_num: Enum.count(players_add),
      players_add: players_add
    })
    for player <- players do
      if player.player_pid != self do
        Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.SpawnPlayer{
          entity_id: player.eid,
          player_uuid: player.uuid,
          x: 0, y: 90, z: 0,
          yaw: 0, pitch: 0,
          current_item: 0,
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
    Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.PlayerListItem{
      action: 4,
      element_num: Enum.count(player_leave),
      players_remove: player_leave
    })
    :ok
  end

end
