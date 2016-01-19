defmodule McEx.Player.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: McEx.Player.Supervisor])
  end

  def start_player(connection, player) do
    Supervisor.start_child(McEx.Player.Supervisor, [connection, player])
  end

  def init(:ok) do
    children = [
      worker(McEx.Player, [], restart: :temporary)
    ]

    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end
end

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

  def get_player_list_info_message(state) do
    %PlayerListInfo{name: state.name, uuid: state.uuid}
  end

  def init({{connection, reader, writer}, {name, uuid}}) do
    Logger.info("User #{name} joined with uuid #{uuid}")
    Process.monitor(connection)

    world_id = :test
    world_pid = McEx.World.Manager.get_world(world_id)
    Process.monitor(world_pid)
    chunk_manager_pid = McEx.World.get_chunk_manager(world_pid)

    state = %PlayerState{
      connection: connection,
      reader: reader,
      writer: writer,
      name: name,
      uuid: uuid,
      world_id: world_id,
      world_pid: world_pid,
      chunk_manager_pid: chunk_manager_pid}

    :gproc.reg({:p, :l, :server_player})
    :gproc.send({:p, :l, {:world_player, world_id}}, get_player_list_info_message(state))
    :gproc.send({:p, :l, {:world_player, world_id}}, {:send_player_list_info, self()})
    McEx.World.PlayerTracker.player_join(world_id)

    Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.PlayerListItem{
      action: 0,
      element_num: 1,
      players_add: [%{
          uuid: 0,
          name: "test",
          property_num: 0,
          properties: [],
          gamemode: 0,
          ping: 0,
          has_display_name: false,
          display_name: nil
        }]
    })

    #McEx.Chunk.Manager.lock_chunk(chunk_manager_pid, {:chunk, 0, 0}, self)
    #{:ok, chunk} = McEx.Chunk.Manager.get_chunk(chunk_mananger_pid, {:chunk, 0, 0})
    #McEx.Chunk.send_chunk(chunk, writer)
    {:ok, state}
  end

  def get_chunks_in_view(%PlayerState{position: pos, client_settings: %ClientSettings{view_distance: view_distance}}) do
    {:chunk, chunk_x, chunk_z} = player_chunk = Pos.to_chunk(pos)
    radius = min(view_distance, 20) #TODO: Setting
    
    chunks_in_view = Enum.flat_map((chunk_x - radius)..(chunk_x + radius), fn(a) -> 
          Enum.map((chunk_z - radius)..(chunk_z + radius), fn(b) -> 
            {ChunkPos.distance(player_chunk, {:chunk, 16 * a + 8, 16 * b + 8}), {a, b}} 
          end)
      end)
    Enum.map(Enum.sort(chunks_in_view, fn({dist1, _}, {dist2, _}) -> dist1 <= dist2 end), fn {_, {x, y}} -> {:chunk, x, y} end)
  end

  def load_chunks(%PlayerState{chunk_manager_pid: manager} = state) do
    chunk_load_list = get_chunks_in_view(state)
    loaded_chunks = Enum.reduce(chunk_load_list, state.loaded_chunks, fn element, loaded ->
      if Set.member?(loaded, element) do
        loaded
      else
        McEx.Chunk.Manager.lock_chunk(manager, element, self)
        {:ok, chunk} = McEx.Chunk.Manager.get_chunk(manager, element)
        McEx.Chunk.send_chunk(chunk, state.writer)
        Set.put(loaded, element)
      end
    end)
    loaded_chunks = Enum.into(Enum.filter(loaded_chunks, fn element ->
      if Enum.member?(chunk_load_list, element) do
        true
      else
        McEx.Chunk.Manager.release_chunk(manager, element, self)
        {:chunk, x, z} = element
        Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.ChunkData{
          chunk_x: x,
          chunk_z: z,
          continuous: true,
          section_mask: 0,
          chunk_data: <<0::8>>})
        false
      end
    end), HashSet.new)

    %{state | loaded_chunks: loaded_chunks}
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

  def handle_cast({:client_event, {:set_pos, pos}}, state) do
    state = %{state | position: pos}
    state = load_chunks(state)
    :gproc.send({:world_member, state.world_id}, {:server_event, {:set_pos, state.name, pos}})
    {:noreply, state} #TODO: Verify movement
  end
  def handle_cast({:client_event, {:set_look, look}}, data) do
    {:noreply, %{data | look: look}}
  end
  def handle_cast({:client_event, {:set_on_ground, on_ground}}, data) do
    {:noreply, %{data | on_ground: on_ground}}
  end
  def handle_cast({:client_event, {:set_view_distance, distance}}, data) do
    {:noreply, update_in(data.client_settings.view_distance, fn _ -> distance end)}
  end

  def handle_cast({:client_event, {:action_digging, state, position, face}}, data) do
    {:noreply, data}
  end

  def handle_cast({:client_event, {:action_punch_animation}}, data) do
    {:noreply, data}
  end
  def handle_cast({:client_event, event}, data) do
    IO.inspect event
    {:noreply, data}
  end

  def handle_info({:server_event, {:set_pos, player_name, pos}}, state) do
    {:noreply, state}
  end

  def handle_info({:send_player_list_info, dest}, state) do
    send(dest, get_player_list_info_message(state))
    {:noreply, state}
  end

  @doc """
  This is sent by other player controllers when they have an update for the player list.
  """
  def handle_info(%PlayerListInfo{}, state) do
    {:noreply, state}
  end
end
