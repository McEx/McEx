defmodule McEx.Net.HandlerClauses do
  alias McEx.Player
  alias McProtocol.Packet.{Server, Server}
  require Logger

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
      {:send_packet,
       %Server.Play.SpawnEntity{
         entity_id: 1001,
         object_uuid: McProtocol.UUID.uuid4,
         type: 2,
         x: 1,
         y: 100,
         z: 1,
         pitch: 0,
         yaw: 0,
         int_field: 1,
         velocity_x: 0,
         velocity_y: 0,
         velocity_z: 0,
       }},
      {:send_packet,
       %Server.Play.EntityMetadata{
         entity_id: 1001,
         metadata: [{5, :slot, %McProtocol.DataTypes.Slot{id: 5}}],
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

    McEx.World.EntitySupervisor.start_entity(world_id, McEx.Entity.Item, %{})

    # TODO: Handle player server crash
    #GenServer.call(state.protocol_state.connection.control, {:die_with, player_server})

    state =
      %{state |
         player: player_server,
         entity_id: entity_id,
       }

    {transitions, state}
  end

end
