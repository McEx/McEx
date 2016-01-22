defmodule McEx.Player do
  use GenServer
  use McEx.Util
  require Logger
  alias McEx.Net.Connection.Write

  defmodule PlayerLook, do: defstruct(yaw: 0, pitch: 0)

  defmodule ClientSettings do
    defmodule SkinParts do
      defstruct(
          cape: true,
          jacket: true,
          left_sleeve: true,
          right_sleeve: true,
          left_pants: true,
          right_pants: true,
          hat: true)
    end
    defstruct(
        locale: "en_GB", 
        view_distance: 8, 
        chat_mode: :enabled, 
        chat_colors: true, 
        skin_parts: nil)
  end

  defmodule PlayerState do
    defstruct(
        eid: nil,
        name: nil,
        uuid: nil,
        connection: nil,
        reader: nil,
        writer: nil,
        position: {:pos, 0, 90, 0},
        look: %PlayerLook{},
        on_ground: true,
        client_settings: %ClientSettings{},
        loaded_chunks: HashSet.new,
        world_id: nil,
        world_pid: nil,
        chunk_manager_pid: nil,
        tracked_players: [])
  end
  defmodule PlayerListInfo do 
    defstruct(name: nil, uuid: nil)
  end

  def start_link(conn, {true, name, uuid}, opts \\ []) do
    GenServer.start_link(__MODULE__, {conn, {name, uuid}}, opts)
  end

  def client_events(_, []), do: nil
  def client_events(server, [event | events]) do
    client_event(server, event)
    client_events(server, events)
  end

  def client_event(server, nil), do: nil
  def client_event(server, data) do
    GenServer.cast(server, {:client_event, data})
  end

  def make_player_list_record(state) do
    %McEx.World.PlayerTracker.PlayerListRecord {
      eid: state.eid,
      uuid: state.uuid,
      name: state.name,
      gamemode: 0,
      ping: 0,
    }
  end

  def init({{connection, reader, writer}, {name, uuid}}) do
    Logger.info("User #{name} joined with uuid #{McEx.UUID.hex uuid}")
    Process.monitor(connection)

    world_id = :test
    world_pid = McEx.World.Manager.get_world(world_id)
    Process.monitor(world_pid)
    chunk_manager_pid = McEx.World.get_chunk_manager(world_pid)

    state = %PlayerState{
      connection: connection,
      reader: reader,
      writer: writer,
      eid: GenServer.call(McEx.EntityIdGenerator, :gen_id),
      name: name,
      uuid: uuid,
      world_id: world_id,
      world_pid: world_pid,
      chunk_manager_pid: chunk_manager_pid}

    :gproc.reg({:p, :l, :server_player})
    McEx.World.PlayerTracker.player_join(world_id, make_player_list_record(state))


    #McEx.Chunk.Manager.lock_chunk(chunk_manager_pid, {:chunk, 0, 0}, self)
    #{:ok, chunk} = McEx.Chunk.Manager.get_chunk(chunk_mananger_pid, {:chunk, 0, 0})
    #McEx.Chunk.send_chunk(chunk, writer)
    {:ok, state}
  end

  def handle_cast({:client_event, event}, state) do
    state = McEx.Player.ClientEvent.handle(event, state)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, connection_pid, _reason}, %{connection: connection_pid, name: name} = data) do
    Logger.info("User #{name} left the server")
    {:stop, :normal, data}
  end
  def handle_info({:DOWN, _ref, :process, world_pid, _reason}, %{world_pid: world_pid} = data) do
    # o shit
    # umm
    # okey
    # i guess we should handle this at some point
    {:stop, :world_down, data}
  end

  def handle_info({:server_event, {:set_pos, player_name, pos}}, state) do
    {:noreply, state}
  end

  def handle_info({:server_event, {:action_chat, message}}, state) do
    {:noreply, state}
  end

  def handle_info({:player_list, :join, players}, state) do
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

    {:noreply, state}
  end
  def handle_info({:player_list, :leave, players}, state) do
    player_leave = for player <- players do
      %{
        uuid: player.uuid
      }
    end

    Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.PlayerListItem{
      action: 4,
      element_num: Enum.count(player_leave),
      players_remove: player_leave
    })

    {:noreply, state}
  end

  def handle_info({:block, :destroy, pos}, state) do
    Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.BlockChange{
      location: pos,
      block_id: 0,
    })
    {:noreply, state}
  end
end
