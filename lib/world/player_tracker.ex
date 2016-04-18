defmodule McEx.World.PlayerTracker do

  defmodule PlayerListRecord do
    defstruct eid: nil, player_pid: nil, mon_ref: nil, uuid: nil, name: nil, gamemode: 0, ping: 0, display_name: nil
  end

  # Client
  def start_link(world_id) do
    GenServer.start_link(__MODULE__, world_id)
  end

  def for_world(world_id) do
    McEx.Registry.world_service_pid(world_id, :world_player_tracker)
  end

  def player_join(world_id, %PlayerListRecord{} = record) do
    GenServer.call(for_world(world_id), {:player_join, %{record | player_pid: self}})
    McEx.Registry.reg_world_player(world_id)
  end

  def player_leave(world_id) do
    McEx.Registry.unreg_world_player(world_id)
    GenServer.call(for_world(world_id), {:player_leave, self})
  end

  # Server
  use GenServer

  def init(world_id) do
    McEx.Registry.reg_world_service(world_id, :world_player_tracker)
    {:ok, %{
        world_id: world_id,
        players: []
      }}
  end

  def handle_call({:player_join, %PlayerListRecord{} = record}, _from, state) do
    state = handle_join(record, state)
    {:reply, state.players, state}
  end
  def handle_call({:player_leave, player_pid}, _from, state) do
    state = handle_leave(player_pid, state)
    {:reply, nil, state}
  end

  def handle_info({:DOWN, mon_ref, _type, _object, _info}, state) do
    player_pid = Enum.find(state.players, fn(rec) -> rec.mon_ref == mon_ref end).player_pid
    state = handle_leave(player_pid, state)
    {:noreply, state}
  end

  def handle_join(%PlayerListRecord{} = record, state) do
    mon_ref = :erlang.monitor(:process, record.player_pid)
    record = %{record | mon_ref: mon_ref}

    message = {:world_event, :player_list, {:join, [record]}}
    McEx.Registry.world_players_send(state.world_id, message)

    state = update_in state.players, &([record | &1])
    message = {:world_event, :player_list, {:join, state.players}}
    send(record.player_pid, message)
    state
  end
  def handle_leave(pid, state) do
    record = Enum.find(state.players, fn(rec) -> rec.player_pid == pid end)
    :erlang.demonitor(record.mon_ref)

    message = {:world_event, :player_list, {:leave, [record]}}
    McEx.Registry.world_players_send(state.world_id, message)

    update_in state.players, &(Enum.filter(&1, fn(rec) -> rec != record end))
  end
end
