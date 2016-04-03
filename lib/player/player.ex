defmodule McEx.Player do
  use GenServer
  use McEx.Util
  require Logger
  alias McEx.Net.Connection.Write
  alias McProtocol.Packet

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
        keepalive_state: nil,
        eid: nil,
        name: nil,
        uuid: nil,
        connection: nil,
        position: {:pos, 0, 100, 0},
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

  def start_link(conn, {true, name, uuid}, entity_id, opts \\ []) do
    GenServer.start_link(__MODULE__, {conn, {name, uuid}, entity_id}, opts)
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

  def init({connection, {name, uuid}, entity_id}) do
    Logger.info("User #{name} joined with uuid #{McProtocol.UUID.hex uuid} (eid: #{entity_id})")
    Process.monitor(connection.control)

    world_id = :test
    world_pid = McEx.World.Manager.get_world(world_id)
    Process.monitor(world_pid)
    chunk_manager_pid = McEx.World.get_chunk_manager(world_pid)

    state = %PlayerState{
      connection: connection,
      eid: entity_id,
      name: name,
      uuid: uuid,
      world_id: world_id,
      world_pid: world_pid,
      chunk_manager_pid: chunk_manager_pid}

    :gproc.reg({:p, :l, :server_player}, {state.name, state.uuid})
    McEx.World.PlayerTracker.player_join(world_id, make_player_list_record(state))

    {:ok, state}
  end

  @doc "Calls the handler for the event we just received from the client."
  def handle_cast({:client_event, event}, state) do
    case McEx.Player.ClientEvent.handle(event, state) do
      {:stop, _, _} = response -> response
      state -> {:noreply, state}
    end
  end

  @doc "Calls the handler for the event we just received from some other process on the server."
  def handle_cast({:server_event, event}, state) do
    case McEx.Player.ServerEvent.handle(:c, event, state) do
      {:stop, _, _} = response -> response
      state -> {:noreply, state}
    end
  end
  @doc "Calls the handler for the event we just received from some other process on the server."
  def handle_info({:server_event, event}, state) do
    case McEx.Player.ServerEvent.handle(:m, event, state) do
      {:stop, _, _} = response -> response
      state -> {:noreply, state}
    end
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

  def handle_info({:block, :destroy, pos}, state) do
    Write.write_packet(state.connection.write, %Packet.Server.Play.BlockChange{
      location: pos,
      type: 0,
    })
    {:noreply, state}
  end
end
