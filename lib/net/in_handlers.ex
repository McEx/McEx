defmodule McEx.Net.LegacyProtocolHandler do
  use McProtocol.Handler

  defmodule HandlerState do
    defstruct mode: :init, name: nil, user: {false, nil, nil}, auth_init_data: nil,
    player: nil, entity_id: nil, protocol_state: nil
  end

  def parent_handler, do: McProtocol.Handler.Login

  def enter({:Client, :Play}, protocol_state) do
    handler_state = %HandlerState{protocol_state: protocol_state}
    McEx.Net.Handlers.join(handler_state)
  end

  def handle(packet_data, state) do
    packet_data = packet_data |> McProtocol.Packet.In.fetch_packet
    McEx.Net.Handlers.handle_packet(state, packet_data.packet)
  end

  def leave(state), do: :disconnect
end

defmodule McEx.Net.Handlers do
  alias McEx.Player
  alias McEx.Net.LegacyProtocolHandler.HandlerState
  alias McEx.Net.ConnectionNew.State
  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server
  require Logger

  def write_packet(state, packet) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(state.protocol_state.connection, packet)
    state
  end

  def join(state) do
    # Hardcoded for now.
    world_id = :test_world

    entity_id = McEx.EntityIdGenerator.get_id(world_id)

    transitions = [
      {:send_packet,
       %Server.Play.Login{
         entity_id: entity_id,
         game_mode: 0, #creative
         dimension: 0, #overworld
         difficulty: 0, #peaceful
         max_players: 10,
         level_type: "default",
         reduced_debug_info: false}},
      {:send_packet,
       %Server.Play.SpawnPosition{
         location: {0, 100, 0}}},
      {:send_packet,
       %Server.Play.Abilities{
         flags: 0b11111111,
         flying_speed: 0.1,
         walking_speed: 0.2}},
      {:send_packet,
       %Server.Play.Position{
         x: 0,
         y: 100,
         z: 0,
         yaw: 0,
         pitch: 0,
         flags: 0}},
      {:send_packet,
       %Server.Play.SpawnEntityLiving{
         entity_id: 1000,
         type: 54,
         x: 0,
         y: 3200,
         z: 0,
         yaw: 0,
         pitch: 0,
         head_pitch: 0,
         velocity_x: 0,
         velocity_y: 0,
         velocity_z: 0,
         metadata: [],
       }}
    ]

    # TODO: Chunks need to sent after JoinGame, and this should be before. Make this work properly with a world system.
    {:ok, player_server} = McEx.Player.Supervisor.start_player(world_id,
                                                               state.protocol_state.connection,
                                                               state.protocol_state.user,
                                                               entity_id)
    # TODO: Handle player server crash
    #GenServer.call(state.protocol_state.connection.control, {:die_with, player_server})

    state = %{ state |
               player: player_server,
               entity_id: entity_id,
             }

    {transitions, state}
  end

  # Play
  def handle_packet(state, %Client.Play.KeepAlive{} = msg) do
    Player.client_event(state.player, {:keep_alive, msg.keep_alive_id})
    {[], state}
  end
  def handle_packet(state, %Client.Play.Chat{} = msg) do
    Player.client_event(state.player, {:action_chat, msg.message})
    {[], state}
  end
  def handle_packet(state, %Client.Play.UseEntity{} = msg) do
    Player.client_event(state.player,
      case msg.type do
        0 -> {:entity_interact, msg.target}
        1 -> {:entity_attack, msg.target}
        2 -> {:entity_interact_at, msg.target, {:pos, msg.x, msg.y, msg.z}}
      end)
    {[], state}
  end

  def handle_packet(state, %Client.Play.Flying{} = msg) do
    Player.client_event(state.player, {:set_on_ground, msg.on_ground})
    {[], state}
  end
  def handle_packet(state, %Client.Play.Position{} = msg) do
    Player.client_event(state.player, {:set_pos, {:pos, msg.x, msg.y, msg.z}, msg.on_ground})
    {[], state}
  end
  def handle_packet(state, %Client.Play.Look{} = msg) do
    Player.client_event(state.player, {:set_look, {:look, msg.yaw, msg.pitch}, msg.on_ground})
    {[], state}
  end
  def handle_packet(state, %Client.Play.PositionLook{} = msg) do
    Player.client_event(state.player, {:set_pos_look, {:pos, msg.x, msg.y, msg.z}, {:look, msg.yaw, msg.pitch}, msg.on_ground})
    {[], state}
  end

  def handle_packet(state, %Client.Play.BlockDig{} = msg) do
    Player.client_event(state.player,
      case msg.status do
        0 -> {:action_digging, :started, msg.location, msg.face}
        1 -> {:action_digging, :cancelled, msg.location, msg.face}
        2 -> {:action_digging, :finished, msg.location, msg.face}
        3 -> {:action_drop_item, :stack}
        4 -> {:action_drop_item, :single}
        5 -> {:action_use_item}
      end)
    {[], state}
  end

  def handle_packet(state, %Client.Play.BlockPlace{location: {:pos, -1, 255, -1}, direction: -1}) do
    # WTF special case :/
    # TODO: Figure this out
    Player.client_event(state.player, {:item_state_update})
    {[], state}
  end
  def handle_packet(state, %Client.Play.BlockPlace{} = msg) do
    Player.client_event(state.player, {:action_place_block, msg.location, msg.direction, msg.held_item, 
      {msg.cursor_x, msg.cursor_y, msg.cursor_z}})
    {[], state}
  end

  def handle_packet(state, %Client.Play.HeldItemSlot{} = msg) do
    Player.client_event(state.player, {:set_held_item, msg.slot})
    {[], state}
  end

  def handle_packet(state, %Client.Play.ArmAnimation{}) do
    Player.client_event(state.player, {:action_punch_animation})
    {[], state}
  end

  def handle_packet(state, %Client.Play.EntityAction{} = msg) do
    Player.client_event(state.player,
      case msg.action_id do
        0 -> {:player_set_crouch, msg.entity_id, true}
        1 -> {:player_set_crouch, msg.entity_id, false}
        2 -> {:player_bed_leave, msg.entity_id}
        3 -> {:player_set_sprint, msg.entity_id, true}
        4 -> {:player_set_sprint, msg.entity_id, false}
        5 -> {:player_horse_jump, msg.entity_id, msg.jump_boost}
        6 -> {:player_open_inventory, msg.entity_id}
      end)
    {[], state}
  end

  def handle_packet(state, %Client.Play.SteerVehicle{} = msg) do
    Player.client_event(state.player, {:set_vehicle_steer, msg.sideways, msg.forward}) #TODO: Flags
    {[], state}
  end

  def handle_packet(state, %Client.Play.CloseWindow{} = msg) do
    Player.client_event(state.player, {:window_close, msg.window_id})
    {[], state}
  end
  def handle_packet(state, %Client.Play.WindowClick{}) do
    # TODO: Handle the complex matrix of click operations :(
    # http://wiki.vg/Protocol#Click_Window
    {[], state}
  end
  def handle_packet(state, %Client.Play.Transaction{}) do
    # TODO: Figure out if I should do something here
    {[], state}
  end
  def handle_packet(state, %Client.Play.SetCreativeSlot{} = msg) do
    Player.client_event(state.player, {:window_creative_set_slot, msg.slot, msg.item})
    {[], state}
  end
  def handle_packet(state, %Client.Play.EnchantItem{} = msg) do
    Player.client_event(state.player, {:window_enchant_item, msg.window_id, msg.enchantment})
    {[], state}
  end

  def handle_packet(state, %Client.Play.UpdateSign{} = msg) do
    Player.client_event(state.player, {:action_update_sign, msg.location, {msg.line_1, msg.line_2, msg.line_3, msg.line_4}})
    {[], state}
  end

  def handle_packet(state, %Client.Play.Abilities{} = msg) do
    <<_::6, is_flying::1, _::1>> = <<msg.flags::unsigned-integer-1*8>>
    Player.client_event(state.player, {:set_flying, is_flying == 1})
    {[], state}
  end

  def handle_packet(state, %Client.Play.TabComplete{} = msg) do
    Player.client_event(state.player, {:action_chat_tab_complete, msg.text, msg.block})
    {[], state}
  end

  def handle_packet(state, %Client.Play.Settings{} = msg) do
    <<cape::1, jacket::1, left_sleeve::1, right_sleeve::1, left_pants::1, right_pants::1, hat::1, _::1>> = <<msg.skin_parts::unsigned-integer-1*8>>

    Player.client_events(state.player, [
      {:set_locale, msg.locale},
      {:set_view_distance, msg.view_distance},
      {:set_chat_mode, case msg.chat_flags do
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

    {[], state}
  end

  def handle_packet(state, %Client.Play.ClientCommand{} = msg) do
    Player.client_event(state.player, 
      case msg.payload do
        0 -> {:action_respawn}
        1 -> {:stats_request}
        2 -> {:stats_achivement, :taking_inventory}
      end)
    {[], state}
  end

  def handle_packet(state, %Client.Play.CustomPayload{} = msg) do
    Player.client_event(state.player, {:plugin_message, msg.channel, msg.data})
    {[], state}
  end

  def handle_packet(state, %Client.Play.Spectate{} = msg) do
    Player.client_event(state.player, {:set_spectate, msg.target_player})
    {[], state}
  end

  def handle_packet(state, %Client.Play.ResourcePackReceive{} = msg) do
    Player.client_event(state.player, {:action_resource_pack_status, msg.hash, msg.result})
    {[], state}
  end
end
