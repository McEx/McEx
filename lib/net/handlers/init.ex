defmodule McEx.Net.Handlers do
  use McEx.Net.HandlerUtils
  require Logger

  def handle_packet(state, %Client.Init.Handshake{next_mode: mode}) do
    State.set_mode(state, case mode do
      1 -> :status
      2 -> :login
    end)
  end
  def handle_packet(%State{} = state, %Client.Status.Request{}) do
    write_packet(state, %Server.Status.Response{response: McEx.Net.Connection.server_list_response})
  end
  def handle_packet(%State{} = state, %Client.Status.Ping{payload: payload}) do
    write_packet(state, %Server.Status.Pong{payload: payload})
  end
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
    state = %{state | user: {true, name, verification_response.id}}

    state = state |> write_packet(%Server.Login.LoginSuccess{
      username: name, 
      uuid: McEx.UUID.hyphenize_string(verification_response.id)})

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
      flags: 0b11111111,
      flying_speed: 0.5,
      walking_speed: 1})
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

  def handle_packet(%State{player: player} = state, %Client.Play.PlayerPositionLook{on_ground: ground} = msg) do
    McEx.Player.recv_position(player, {:pos, msg.x, msg.y, msg.z})
    McEx.Player.recv_look(player, %McEx.Player.PlayerLook{yaw: msg.yaw, pitch: msg.pitch})
    McEx.Player.recv_ground(player, ground)
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.PlayerPosition{on_ground: ground} = msg) do
    McEx.Player.recv_position(player, {:pos, msg.x, msg.y, msg.z})
    McEx.Player.recv_ground(player, ground)
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.PlayerLook{on_ground: ground} = msg) do
    McEx.Player.recv_look(player, %McEx.Player.PlayerLook{yaw: msg.yaw, pitch: msg.pitch})
    McEx.Player.recv_ground(player, ground)
    state
  end
  def handle_packet(%State{player: player} = state, %Client.Play.PlayerGround{on_ground: ground} = action) do
    McEx.Player.recv_ground(player, ground)
    state
  end

  def handle_packet(%State{player: player} = state, %Client.Play.ClientSettings{} = settings) do
    <<cape::1, jacket::1, left_sleeve::1, right_sleeve::1, left_pants::1, right_pants::1, hat::1, _::1>> = settings.skin_parts
    McEx.Player.update_client_settings(player, %McEx.Player.ClientSettings{
      locale: settings.locale,
      view_distance: settings.view_distance,
      chat_mode: case settings.chat_mode do
        0 -> :enabled
        1 -> :commands
        2 -> :hidden
      end,
      chat_colors: settings.chat_colors,
      skin_parts: %McEx.Player.ClientSettings.SkinParts{
        cape: cape == 1,
        jacket: jacket == 1,
        left_sleeve: left_sleeve == 1,
        right_sleeve: right_sleeve == 1,
        left_pants: left_pants == 1,
        right_pants: right_pants == 1}})

    state
  end
  def handle_packet(%State{} = state, %Client.Play.PluginMessage{}) do
    #IO.inspect message
    state
  end
  def handle_packet(%State{} = state, %Client.Play.KeepAlive{nonce: nonce} = ka) do
    #IO.inspect ka
    #state = write_packet(state, %Server.Play.KeepAlive{nonce: nonce})
    state
  end
  def handle_packet(%State{} = state, %Client.Play.ClientStatus{}) do
    state
  end
  def handle_packet(%State{} = state, %Client.Play.CloseWindow{}) do
    state
  end
  def handle_packet(%State{} = state, %Client.Play.CreativeInventoryAction{} = action) do
    IO.inspect action
    state
  end
  def handle_packet(%State{} = state, %Client.Play.EntityAction{} = action) do
    IO.inspect action
    state
  end
  def handle_packet(%State{} = state, %Client.Play.PlayerAbilities{} = action) do
    IO.inspect action
    state
  end

  def handle_packet(%State{} = state, %Client.Play.Animation{} = action) do
    IO.inspect action
    state
  end
  def handle_packet(%State{} = state, %Client.Play.PlayerDigging{} = action) do
    IO.inspect action
    state
  end
end
