defmodule McEx.Player.Property.PlayerList do
  use McEx.Entity.Property

  alias McProtocol.Packet.{Client, Server}

  def initial(state) do
    McEx.World.PlayerTracker.player_join(state.world_id,
                                         make_player_list_record(state))
    state
  end

  def make_player_list_record(state) do
    %McEx.World.PlayerTracker.PlayerListRecord {
      eid: state.eid,
      uuid: state.identity.uuid,
      name: state.identity.name,
      gamemode: 0,
      ping: 0,
    }
  end

  def handle_world_event(:player_list, {:join, records}, state) do
    players_add = for record <- records do
      %{
        uuid: record.uuid,
        name: record.name,
        properties: [],
        gamemode: record.gamemode,
        ping: record.ping,
        has_display_name: false,
        display_name: nil,
      }
    end

    %Server.Play.PlayerInfo{
      action: 0,
      data: players_add}
    |> write_client_packet(state)

    #for record <- records do
    #  if record.player_pid != self do
    #    %Server.Play.NamedEntitySpawn{
    #      entity_id: record.eid,
    #      player_uuid: record.uuid,
    #      x: 0, y: 100, z: 0,
    #      yaw: 0, pitch: 0,
    #      metadata: []}
    #    |> write_client_packet(state)
    #  end
    #end

    state
  end
  def handle_world_event(:player_list, {:leave, records}, state) do
    players_leave = for record <- records do
      %{uuid: record.uuid}
    end

    %Server.Play.PlayerInfo{
      action: 4,
      data: players_leave}
    |> write_client_packet(state)

    state
  end

end
