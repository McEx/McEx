defmodule McEx.World.Shard do
  use GenServer

  alias McEx.MembershipManager

  # Client

  def start_link(world_id, pos) do
    GenServer.start(__MODULE__, {world_id, pos})
  end

  def start_listen(world_id, pos) do
    # We have to synchronize all join and leave operations to
    # prevent race conditions.
    shard_pid = McEx.Registry.shard_server_pid(world_id, pos)
    McEx.Registry.reg_shard_listener(world_id, pos)
    :ok = GenServer.call(shard_pid, {:start_listen, self})
  end
  def stop_listen(world_id, pos) do
    shard_pid = McEx.Registry.shard_server_pid(world_id, pos)
    McEx.Registry.unreg_shard_listener(world_id, pos)
    :ok = GenServer.call(shard_pid, {:stop_listen, self})
  end

  def start_membership(world_id, pos, eid, _from_shard \\ nil) do
    shard_pid = McEx.Registry.shard_server_pid(world_id, pos)
    McEx.Registry.reg_shard_member(world_id, pos)
    :ok = GenServer.call(shard_pid, {:start_membership, self, eid})
  end
  def stop_membership(world_id, pos, _to_shard \\ nil) do
    shard_pid = McEx.Registry.shard_server_pid(world_id, pos)
    McEx.Registry.unreg_shard_member(world_id, pos)
    :ok = GenServer.call(shard_pid, {:stop_membership, self})
  end

  def broadcast(world_id, pos, event_id, eid \\ nil, value) do
    message = {:entity_msg, :shard_broadcast, {pos, eid, event_id, value}}
    McEx.Registry.shard_listener_send(world_id, pos, message)
  end
  def broadcast_members(world_id, pos, event_id, eid \\ nil, value) do
    message = {:entity_msg, :shard_member_broadcast, {pos, eid, event_id, value}}
    McEx.Registry.shard_member_send(world_id, pos, message)
  end

  # Server

  def init({world_id, pos}) do
    McEx.Registry.reg_shard_server(world_id, pos)
    state = %{
      world_id: world_id,
      pos: pos,
      membership: MembershipManager.init([:listeners, :members]),
    }
    {:ok, state}
  end

  def handle_call({:start_listen, process}, _from, state) do
    # TODO: Send catchup messages
    membership = MembershipManager.join!(state.membership, :listeners, process)
    state = %{state | membership: membership}
    {:reply, :ok, state}
  end
  def handle_call({:stop_listen, process}, _from, state) do
    # TODO: Stop the shard if empty?
    {:ok, membership, _} = MembershipManager.leave(state.membership, :listeners,
                                                   process)
    state = %{state | membership: membership}
    {:reply, :ok, state}
  end

  def handle_call({:start_membership, process, eid}, _from, state) do
    membership = MembershipManager.join!(state.membership, :members, process, eid)
    state = %{state | membership: membership}
    {:reply, :ok, state}
  end
  def handle_call({:stop_membership, process}, _from, state) do
    {:ok, membership, eid} = MembershipManager.leave(
      state.membership, :members, process)

    broadcast(state.world_id, state.pos, :entity_exit, eid, nil)

    state = %{state | membership: membership}
    {:reply, :ok, state}
  end

  def handle_info({:DOWN, ref, _, _, _}, state) do
    {:ok, membership, group, eid} = MembershipManager.mon_ref_leave(
      state.membership, ref)

    case group do
      :members ->
        broadcast(state.world_id, state.pos, :entity_exit, eid, nil)
      _ -> nil
    end

    state = %{state | membership: membership}
    {:noreply, state}
  end

end
