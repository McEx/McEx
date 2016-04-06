defmodule McEx.Player do
  use GenServer
  use McEx.Util
  require Logger
  alias McProtocol.Packet

  @type startup_options :: %{
    connection: term,
    entity_id: integer,
    user: {bool, string, %McProtocol.UUID{}},
  }

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
        authed: nil,
        name: nil,
        uuid: nil,
        connection: nil,
        position: {:pos, 0, 100, 0},
        look: %PlayerLook{},
        on_ground: true,
        client_settings: %ClientSettings{},
        loaded_chunks: HashSet.new,
        world_id: nil,
        tracked_players: [])
  end
  defmodule PlayerListInfo do
    defstruct(name: nil, uuid: nil)
  end

  @spec start_link(term, startup_options)
  def start_link(world_id, options) do
    GenServer.start_link(__MODULE__, {world_id, options})
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

  def init({world_id, options}) do
    {authed, name, uuid} = options.user
    Logger.info("User #{name} joined with uuid #{McProtocol.UUID.hex uuid}")
    Process.monitor(options.connection.control)

    state = %PlayerState{
      connection: options.connection,
      eid: options.entity_id,
      authed: authed,
      name: name,
      uuid: uuid,
      world_id: world_id,
    }

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

  def handle_info({:block, :destroy, pos}, state) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(
      state.connection,
      %Packet.Server.Play.BlockChange{
        location: pos,
        type: 0,
      })
    {:noreply, state}
  end
end
