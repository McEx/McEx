defmodule McEx.Net.Handlers do
  use McEx.Net.HandlerUtils
  alias McEx.Player
  require Logger

  # Init
  def handle_packet(state, %Client.Init.Handshake{next_mode: mode}) do
    State.set_mode(state, case mode do
      1 -> :status
      2 -> :login
    end)
  end

  # Status
  def handle_packet(%State{} = state, %Client.Status.Request{}) do
    write_packet(state, %Server.Status.Response{response: McEx.Net.Connection.server_list_response})
  end
  def handle_packet(%State{} = state, %Client.Status.Ping{payload: payload}) do
    write_packet(state, %Server.Status.Pong{payload: payload})
  end

  # Login
  def handle_packet(%State{} = state, %Client.Login.LoginStart{name: name} = s) do
    auth_init_data = {{pubkey, _}, token} = McEx.Net.Crypto.get_auth_init_data
    state = write_packet(state, %Server.Login.EncryptionRequest{server_id: "", public_key: pubkey, verify_token: token})
    %State{state | name: name, user: {false, name, nil}, auth_init_data: auth_init_data}
  end
  def handle_packet(
        %State{auth_init_data: {{pub_key, priv_key}, token}, name: name} = state, 
        %Client.Login.EncryptionResponse{shared_secret: encr_shared_secret, verify_token: encr_token}) do

    ^token = :public_key.decrypt_private(encr_token, priv_key)
    shared_secret = :public_key.decrypt_private(encr_shared_secret, priv_key)
    16 = byte_size(shared_secret)

    state = state |> set_encr(%McEx.Net.Crypto.CryptData{key: shared_secret, ivec: shared_secret})

    verification_response = Crypto.verify_user_login(pub_key, shared_secret, name)
    ^name = verification_response.name
    uuid = McEx.UUID.from_hex(verification_response.id)
    state = %{state | user: {true, name, uuid}}

    state = state |> write_packet(%Server.Login.LoginSuccess{
      username: name, 
      uuid: uuid})

    state = State.set_mode(state, :play)
    state = %{state | entity_id: McEx.EntityIdGenerator.get_id}

    state = state |> write_packet(%Server.Play.JoinGame{
      entity_id: state.entity_id,
      gamemode: 0, #creative
      dimension: 0, #overworld
      difficulty: 0, #peaceful
      max_players: 10,
      level_type: "default",
      reduced_debug_info: false})

    # TODO: Chunks need to sent after JoinGame, and this should be before. Make this work properly with a world system.
    {:ok, player_server} = McEx.Player.Supervisor.start_player({state.socket_manager, self, state.write}, state.user)
    state = %{state | player: player_server}

    #SpawnPosition
    state = write_packet(state, %Server.Play.SpawnPosition{
      location: {0, 90, 0}})
    #PlayerAbilities
    state = write_packet(state, %Server.Play.PlayerAbilities{
      flags: <<0b11111111::8>>,
      flying_speed: 0.1,
      walking_speed: 0.2})
    #PlayerPositionLook
    state = write_packet(state, %Server.Play.PlayerPositionLook{
      x: 0,
      y: 90,
      z: 0,
      yaw: 0,
      pitch: 0,
      flags: 0})

    state
  end

  # Play
  def handle_packet(%State{player: player} = state, %Client.Play.KeepAlive{} = msg) do
    Player.client_event(player, {:keep_alive, msg.nonce})
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.ChatMessage{} = msg) do
    Player.client_event(player, {:action_chat, msg.message})
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.UseEntity{} = msg) do
    Player.client_event(player, 
      case msg.type do
        0 -> {:entity_interact, msg.target}
        1 -> {:entity_attack, msg.target}
        2 -> {:entity_interact_at, msg.target, {:pos, msg.x, msg.y, msg.z}}
      end)
  end

  def handle_packet(%State{player: player} = state, %Client.Play.PlayerGround{} = msg) do
    Player.client_event(player, {:set_on_ground, msg.on_ground})
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.PlayerPosition{} = msg) do
    Player.client_events(player, [
      {:set_pos, {:pos, msg.x, msg.y, msg.z}},
      {:set_on_ground, msg.on_ground}])
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.PlayerLook{} = msg) do
    Player.client_events(player, [
      {:set_look, {:look, msg.yaw, msg.pitch}},
      {:set_on_ground, msg.on_ground}])
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.PlayerPositionLook{} = msg) do
    Player.client_events(player, [
      {:set_pos, {:pos, msg.x, msg.y, msg.z}},
      {:set_look, {:look, msg.yaw, msg.pitch}},
      {:set_on_ground, msg.on_ground}])
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.PlayerDigging{} = msg) do
    Player.client_event(player,
      case msg.status do
        0 -> {:action_digging, :started, msg.location, msg.face}
        1 -> {:action_digging, :cancelled, msg.location, msg.face}
        2 -> {:action_digging, :finished, msg.location, msg.face}
        3 -> {:action_drop_item, :stack}
        4 -> {:action_drop_item, :single}
        5 -> {:action_use_item}
      end)
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.PlayerBlockPlacement{location: {:pos, -1, 255, -1}, face: -1}) do
    # WTF special case :/
    # TODO: Figure this out
    Player.client_event(player, {:item_state_update})
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.PlayerBlockPlacement{} = msg) do
    Player.client_event(player, {:action_place_block, msg.location, msg.face, msg.held_item, 
      {msg.cursor_x, msg.cursor_y, msg.cursor_z}})
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.HeldItemChange{} = msg) do
    Player.client_event(player, {:set_held_item, msg.slot})
  end

  def handle_packet(%State{player: player} = state, %Client.Play.Animation{}) do
    Player.client_event(player, {:action_punch_animation})
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.EntityAction{} = msg) do
    Player.client_event(player,
      case msg.action_id do
        0 -> {:player_set_crouch, msg.entity_id, true}
        1 -> {:player_set_crouch, msg.entity_id, false}
        2 -> {:player_bed_leave, msg.entity_id}
        3 -> {:player_set_sprint, msg.entity_id, true}
        4 -> {:player_set_sprint, msg.entity_id, false}
        5 -> {:player_horse_jump, msg.entity_id, msg.jump_boost}
        6 -> {:player_open_inventory, msg.entity_id}
      end)
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.SteerVehicle{} = msg) do
    Player.client_event(player, {:set_vehicle_steer, msg.sideways, msg.forward}) #TODO: Flags
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.CloseWindow{} = msg) do
    Player.client_event(player, {:window_close, msg.window_id})
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.ClickWindow{}) do
    # TODO: Handle the complex matrix of click operations :(
    # http://wiki.vg/Protocol#Click_Window
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.ConfirmTransaction{}) do
    # TODO: Figure out if I should do something here
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.CreativeInventoryAction{} = msg) do
    Player.client_event(player, {:window_creative_set_slot, msg.slot, msg.item})
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.EnchantItem{} = msg) do
    Player.client_event(player, {:window_enchant_item, msg.window_id, msg.enchantment})
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.UpdateSign{} = msg) do
    Player.client_event(player, {:action_update_sign, msg.location, {msg.line_1, msg.line_2, msg.line_3, msg.line_4}})
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.PlayerAbilities{} = msg) do
    <<_::6, is_flying::1, _::1>> = msg.flags
    Player.client_event(player, {:set_flying, is_flying == 1})
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.TabComplete{} = msg) do
    Player.client_event(player, {:action_chat_tab_complete, msg.text, msg.block_look})
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.ClientSettings{} = msg) do
    <<cape::1, jacket::1, left_sleeve::1, right_sleeve::1, left_pants::1, right_pants::1, hat::1, _::1>> = msg.skin_parts

    Player.client_events(player, [
      {:set_locale, msg.locale},
      {:set_view_distance, msg.view_distance},
      {:set_chat_mode, case msg.chat_mode do
        0 -> :enabled
        1 -> :commands
        2 -> :hidden
      end},
      {:set_chat_colors, msg.chat_colors},
      {:set_skin_parts, %McEx.Player.ClientSettings.SkinParts{
        cape: cape == 1,
        jacket: jacket == 1,
        left_sleeve: left_sleeve == 1,
        right_sleeve: right_sleeve == 1,
        left_pants: left_pants == 1,
        right_pants: right_pants == 1}}])

    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.ClientStatus{} = msg) do
    Player.client_event(player, 
      case msg.action_id do
        0 -> {:action_respawn}
        1 -> {:stats_request}
        2 -> {:stats_achivement, :taking_inventory}
      end)
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.PluginMessage{} = msg) do
    Player.client_event(player, {:plugin_message, msg.channel, msg.data})
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.Spectate{} = msg) do
    Player.client_event(player, {:set_spectate, msg.target_player})
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.ResourcePackStatus{} = msg) do
    Player.client_event(player, {:action_resource_pack_status, msg.hash, msg.result})
    state
  end
end
