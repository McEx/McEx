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
      {:send_packet, %Server.Play.Login{
         entity_id: entity_id,
         game_mode: 0, #survival
         dimension: 0, #overworld
         difficulty: 0, #peaceful
         max_players: 10,
         level_type: "default",
        reduced_debug_info: false,
        }},
      {:send_packet, %Server.Play.SpawnPosition{
         location: {0, 100, 0}}},
      {:send_packet, %Server.Play.Abilities{
         flags: 0b11111111,
         flying_speed: 0.1,
        walking_speed: 0.2,
        }},
      {:send_packet, %Server.Play.Position{
         x: 0,
         y: 100,
         z: 0,
         yaw: 0,
         pitch: 0,
         flags: 0,
         teleport_id: 0,
        }},

      {:send_packet, %Server.Play.SpawnEntityLiving{
         entity_id: 1000,
         entity_uuid: McProtocol.UUID.uuid4,
         type: 54,
         x: 0,
         y: 110,
         z: 0,
         yaw: 0,
         pitch: 0,
         head_pitch: 0,
         velocity_x: 0,
         velocity_y: 0,
         velocity_z: 0,
         metadata: [],
       }},
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
      %{state |
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
      case msg.mouse do
        0 -> {:entity_interact, msg.target}
        1 -> {:entity_attack, msg.target}
        2 -> {:entity_interact_at, msg.target, {:pos, msg.x, msg.y, msg.z}}
      end)
    {[], state}
  end
  def handle_packet(%Client.Play.TeleportConfirm{} = msg, stash, state) do
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
        5 -> {:action_deactivate_item}
        6 -> {:action_swap_item}
        status -> raise "unexpected block dig status: #{status}"
      end)
    {[], state}
  end

  def handle_packet(%Client.Play.UseItem{hand: hand}, stash, state) do
    hand = if hand == 0, do: :main_hand, else: :off_hand # or just pass the hand nr
    Player.client_event(state.player, {:action_activate_item, hand})
    {[], state}
  end
  def handle_packet(
        %Client.Play.BlockPlace{location: {:pos, -1, 255, -1}, direction: -1},
        stash, state) do
    # there is UseItem now in 1.9, (when) is this used? what hand/item gets activated?
    raise "BlockPlace used for activating an item, investigate"
    Player.client_event(state.player, {:action_activate_item, nil})
    {[], state}
  end
  def handle_packet(%Client.Play.BlockPlace{direction: direction} = msg,
        stash, state) when direction >= 0 and direction < 6 do
    hand = if msg.hand == 0, do: :main_hand, else: :off_hand # or just pass the hand nr
    message = {:action_place_block, msg.location, direction, hand,
               {msg.cursor_x, msg.cursor_y, msg.cursor_z}}
    Player.client_event(state.player, message)
    {[], state}
  end

  def handle_packet(%Client.Play.ArmAnimation{}, stash, state) do
    Player.client_event(state.player, {:action_punch_animation})
    {[], state}
  end

  def handle_packet(%Client.Play.EntityAction{} = msg, stash, state) do
    Player.client_event(state.player,
      case msg.action_id do
        0 -> {:player_set_crouch, true} # TODO this does not set crouch when in a vehicle
        1 -> {:player_set_crouch, false}
        2 -> :player_bed_leave
        3 -> {:player_set_sprint, true}
        4 -> {:player_set_sprint, false}
        5 -> {:player_horse_jump, msg.jump_boost}
        6 -> :player_open_inventory
        action_id -> raise "unknown entity action: #{action_id}"
      end)
    {[], state}
  end

  def handle_packet(%Client.Play.SteerVehicle{} = msg, stash, state) do
    #TODO: Flags
    Player.client_event(state.player, {:set_vehicle_steer, msg.sideways, msg.forward})
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

  def handle_packet(%Client.Play.ClientCommand{} = msg, stash, state) do
    Player.client_event(state.player,
      case msg.action_id do
        0 -> {:action_respawn}
        1 -> {:stats_request}
        2 -> {:stats_achievement, :taking_inventory}
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

  def handle_packet(msg, stash, state) do
    {[], state}
  end

end
