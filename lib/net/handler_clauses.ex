defmodule McEx.Net.HandlerClauses do
  alias McEx.Player
  alias McEx.Net.LegacyProtocolHandler.HandlerState
  alias McEx.Net.ConnectionNew.State
  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server
  require Logger

  def write_packet(packet, stash) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(stash.connection, packet)
    stash
  end

  def join(stash, state) do
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
    {:ok, player_server} = McEx.World.EntitySupervisor.start_entity(
      world_id, McEx.Player,
      %{
        connection: stash.connection,
        identity: stash.identity,
        entity_id: entity_id,
      }
    )

    # TODO: Handle player server crash
    #GenServer.call(state.protocol_state.connection.control, {:die_with, player_server})

    state =
      %{ state |
         player: player_server,
         entity_id: entity_id,
       }

    {transitions, state}
  end

  # Play
  def handle_packet(%Client.Play.KeepAlive{} = msg, stash, state) do
    Player.client_event(state.player, {:keep_alive, msg.keep_alive_id})
    {[], state}
  end
  def handle_packet(%Client.Play.Chat{} = msg, stash, state) do
    Player.client_event(state.player, {:action_chat, msg.message})
    {[], state}
  end
  def handle_packet(%Client.Play.UseEntity{} = msg, stash, state) do
    Player.client_event(state.player,
      case msg.type do
        0 -> {:entity_interact, msg.target}
        1 -> {:entity_attack, msg.target}
        2 -> {:entity_interact_at, msg.target, {:pos, msg.x, msg.y, msg.z}}
      end)
    {[], state}
  end

  def handle_packet(%Client.Play.Flying{} = msg, stash, state) do
    Player.client_event(state.player, {:set_on_ground, msg.on_ground})
    {[], state}
  end
  def handle_packet(%Client.Play.Position{} = msg, stash, state) do
    Player.client_event(state.player, {:set_pos, {:pos, msg.x, msg.y, msg.z}, msg.on_ground})
    {[], state}
  end
  def handle_packet(%Client.Play.Look{} = msg, stash, state) do
    Player.client_event(state.player, {:set_look, {:look, msg.yaw, msg.pitch}, msg.on_ground})
    {[], state}
  end
  def handle_packet(%Client.Play.PositionLook{} = msg, stash, state) do
    Player.client_event(state.player, {:set_pos_look, {:pos, msg.x, msg.y, msg.z}, {:look, msg.yaw, msg.pitch}, msg.on_ground})
    {[], state}
  end

  def handle_packet(%Client.Play.BlockDig{} = msg, stash, state) do
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

  def handle_packet(
        %Client.Play.BlockPlace{location: {:pos, -1, 255, -1}, direction: -1},
        stash, state) do
    # WTF special case :/
    # TODO: Figure this out
    Player.client_event(state.player, {:item_state_update})
    {[], state}
  end
  def handle_packet(%Client.Play.BlockPlace{} = msg, stash, state) do
    message = {:action_place_block, msg.location, msg.direction, msg.held_item,
               {msg.cursor_x, msg.cursor_y, msg.cursor_z}}
    Player.client_event(state.player, message)
    {[], state}
  end

  def handle_packet(%Client.Play.HeldItemSlot{} = msg, stash, state) do
    Player.client_event(state.player, {:set_held_item, msg.slot})
    {[], state}
  end

  def handle_packet(%Client.Play.ArmAnimation{}, stash, state) do
    Player.client_event(state.player, {:action_punch_animation})
    {[], state}
  end

  def handle_packet(%Client.Play.EntityAction{} = msg, stash, state) do
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

  def handle_packet(%Client.Play.SteerVehicle{} = msg, stash, state) do
    #TODO: Flags
    Player.client_event(state.player, {:set_vehicle_steer, msg.sideways, msg.forward})
    {[], state}
  end

  def handle_packet(%Client.Play.CloseWindow{} = msg, stash, state) do
    Player.client_event(state.player, {:window_close, msg.window_id})
    {[], state}
  end
  def handle_packet(%Client.Play.WindowClick{}, stash, state) do
    # TODO: Handle the complex matrix of click operations :(
    # http://wiki.vg/Protocol#Click_Window
    {[], state}
  end
  def handle_packet(%Client.Play.Transaction{}, stash, state) do
    # TODO: Figure out if I should do something here
    {[], state}
  end
  def handle_packet(%Client.Play.SetCreativeSlot{} = msg, stash, state) do
    Player.client_event(state.player, {:window_creative_set_slot, msg.slot, msg.item})
    {[], state}
  end
  def handle_packet(%Client.Play.EnchantItem{} = msg, stash, state) do
    Player.client_event(state.player, {:window_enchant_item, msg.window_id, msg.enchantment})
    {[], state}
  end

  def handle_packet(%Client.Play.UpdateSign{} = msg, stash, state) do
    message = {:action_update_sign, msg.location,
               {msg.line_1, msg.line_2, msg.line_3, msg.line_4}}
    Player.client_event(state.player, message)
    {[], state}
  end

  def handle_packet(%Client.Play.Abilities{} = msg, stash, state) do
    <<_::6, is_flying::1, _::1>> = <<msg.flags::unsigned-integer-1*8>>
    Player.client_event(state.player, {:set_flying, is_flying == 1})
    {[], state}
  end

  def handle_packet(%Client.Play.TabComplete{} = msg, stash, state) do
    Player.client_event(state.player, {:action_chat_tab_complete, msg.text, msg.block})
    {[], state}
  end

  def handle_packet(%Client.Play.Settings{} = msg, stash, state) do
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

  def handle_packet(%Client.Play.ClientCommand{} = msg, stash, state) do
    Player.client_event(state.player,
      case msg.payload do
        0 -> {:action_respawn}
        1 -> {:stats_request}
        2 -> {:stats_achivement, :taking_inventory}
      end)
    {[], state}
  end

  def handle_packet(%Client.Play.CustomPayload{} = msg, stash, state) do
    Player.client_event(state.player, {:plugin_message, msg.channel, msg.data})
    {[], state}
  end

  def handle_packet(%Client.Play.Spectate{} = msg, stash, state) do
    Player.client_event(state.player, {:set_spectate, msg.target_player})
    {[], state}
  end

  def handle_packet(%Client.Play.ResourcePackReceive{} = msg, stash, state) do
    Player.client_event(state.player, {:action_resource_pack_status, msg.hash, msg.result})
    {[], state}
  end
end
