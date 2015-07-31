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
        loaded_chunks: HashSet.new)
  end

  def start_link(conn, {true, name, uuid}, opts \\ []) do
    GenServer.start_link(__MODULE__, {conn, {name, uuid}}, opts)
  end

  def recv_position(server, {:pos, _, _, _} = pos) do
    GenServer.cast(server, {:update_position, pos})
  end
  def recv_look(server, %PlayerLook{} = look) do
    GenServer.cast(server, {:update_look, look})
  end
  def recv_ground(server, on_ground) do
    GenServer.cast(server, {:on_ground, on_ground})
  end
  def update_client_settings(server, %ClientSettings{} = settings) do
    GenServer.cast(server, {:update_client_settings, settings})
  end

  def init({{connection, reader, writer}, {name, uuid}}) do
    Logger.info("User #{name} joined with uuid #{uuid}")
    Process.monitor(connection)
    McEx.Chunk.Manager.lock_chunk({:chunk, 0, 0}, self)
    {:ok, chunk} = McEx.Chunk.Manager.get_chunk({:chunk, 0, 0})
    McEx.Chunk.send_chunk(chunk, writer)
    {:ok, %PlayerState{
        connection: connection,
        reader: reader,
        writer: writer,
        name: name,
        uuid: uuid}}
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

  def load_chunks(%PlayerState{} = state) do
    chunk_load_list = get_chunks_in_view(state)
    loaded_chunks = Enum.reduce(chunk_load_list, state.loaded_chunks, fn element, loaded ->
      if Set.member?(loaded, element) do
        loaded
      else
        McEx.Chunk.Manager.lock_chunk(element, self)
        {:ok, chunk} = McEx.Chunk.Manager.get_chunk(element)
        McEx.Chunk.send_chunk(chunk, state.writer)
        Set.put(loaded, element)
      end
    end)
    loaded_chunks = Enum.into(Enum.filter(loaded_chunks, fn element ->
      if Enum.member?(chunk_load_list, element) do
        true
      else
        McEx.Chunk.Manager.release_chunk(element, self)
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

  def handle_cast({:update_position, {:pos, _, _, _} = pos}, state) do
    state = %{state | position: pos}
    state = load_chunks(state)
    {:noreply, state} #TODO: Verify movement
  end
  def handle_cast({:update_look, %PlayerLook{} = look}, data) do
    {:noreply, %{data | look: look}}
  end
  def handle_cast({:on_ground, on_ground}, data) do
    {:noreply, %{data | on_ground: on_ground}}
  end
  def handle_cast({:update_client_settings, %ClientSettings{skin_parts: %ClientSettings.SkinParts{}} = settings}, data) do
    IO.inspect settings
    {:noreply, %{data | client_settings: settings}}
  end
end
