defmodule McEx.Player do
  use GenServer
  use McEx.Util
  require Logger

  # Client

  @type startup_options :: %{
    connection: term,
    entity_id: any,
    user: {boolean, String.t, %McProtocol.UUID{}},
  }

  @spec start_link(term, startup_options) :: GenServer.on_start
  def start_link(world_id, options) do
    GenServer.start_link(__MODULE__, {world_id, options})
  end

  def client_packet(pid, packet) do
    message = {:entity_msg, :client_packet, packet}
    send pid, message
    #GenServer.cast(pid, message)
  end

  def player_eid(server) do
    GenServer.call(server, :get_entity_id)
  end

  # Server

  defmodule PlayerState do
    defstruct(
      # General
      eid: nil,
      world_id: nil,
      properties: %{},

      # Player spesific
      connection: nil,
      identity: nil,
    )
  end

  @properties [
    McEx.Player.Property.Keepalive,
    McEx.Entity.Property.Spawn,

    McEx.Entity.Property.Position,
    McEx.Player.Property.PlayerList,

    McEx.Player.Property.Movement,
    McEx.Entity.Property.Shards,
    McEx.Player.Property.Entities,

    McEx.Player.Property.ClientSettings,
    McEx.Player.Property.Windows,

    McEx.Player.Property.Chunks,
    McEx.Player.Property.BlockInteract,
    McEx.Player.Property.Inventory,
    McEx.Player.Property.Chat,
  ]

  def init({world_id, options}) do
    %{name: name, uuid: uuid} = options.identity
    Logger.info("User #{name} joined with uuid #{McProtocol.UUID.hex uuid}")
    Process.monitor(options.connection.control)

    prop_options = %{
      McEx.Entity.Property.Spawn =>
      %{
        type: :player,
        uuid: uuid,
      },
    }

    state = %PlayerState{
      # General
      eid: options.entity_id,
      world_id: world_id,
      properties: %{},

      # Player spesific
      connection: options.connection,
      identity: options.identity,
    }
    |> McEx.Entity.Property.initial_properties(@properties, prop_options)

    {:ok, state}
  end

  def handle_call(:get_entity_id, _from, state) do
    {:reply, state.eid, state}
  end

  def handle_call({:debug_exec, fun}, _from, state) do
    case fun.(state) do
      {response, state} -> {:reply, response, state}
      state -> {:reply, nil, state}
    end
  end

  def handle_info({:entity_msg, type, body}, state) do
    state = Enum.reduce(state.properties, state, fn({mod, _}, state) ->
      apply(mod, :handle_entity_msg, [type, body, state])
    end)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, connection_pid, reason},
                  %{connection: %{control: connection_pid}} = state) do
    Logger.info("User #{state.identity.name} left the server")
    Logger.debug("reason: #{inspect reason}")
    {:stop, :normal, state}
  end
end
