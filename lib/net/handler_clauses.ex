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
      {:send_packet, %Server.Play.Abilities{
         flags: 0b11111111,
         flying_speed: 0.1,
        walking_speed: 0.2,
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
  def handle_packet(%Client.Play.Chat{} = msg, stash, state) do
    Player.client_event(state.player, {:action_chat, msg.message})
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

  def handle_packet(msg, stash, state) do
    {[], state}
  end

end
