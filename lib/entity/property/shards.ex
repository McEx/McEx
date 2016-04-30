defmodule McEx.Entity.Property.Shards do
  use McEx.Entity.Property
  use McEx.Util
  require Logger

  alias McEx.Math

  @moduledoc """
  Handles shard membership for an entity.

  It depends on:
  * McEx.Entity.Property.Position
  """

  @shard_size 4

  defp calc_pos_shard(pos) do
    {:chunk, cx, cz} = Pos.to_chunk(pos)
    {Math.floor(cx / @shard_size) * @shard_size,
     Math.floor(cz / @shard_size) * @shard_size,}
  end

  def initial(_args, state) do
    # TODO: Currently the client will only join a shard on the current move event.
    # Do we want to change this?

    prop = %{
      current_shard: nil,
      shards: MapSet.new,
      view_distance: 8,
    }
    state = set_prop(state, prop)
    state = join_leave_shards(state)

    state
  end


  @doc """
  Handles a movement of the current entity.

  Does shard transitioning.
  """
  def handle_prop_event(:move, _, state) do
    join_leave_shards(state)
  end

  @doc """
  This will take care of transitioning between shards.
  This includes managing shard membership and shard listens.

  TODO: Make this only execute at a certain block interval to prevent running
  on every move event sent by the player client.
  """
  def join_leave_shards(state) do
    pos = McEx.Entity.Property.Position.get_position(state).pos
    current_shard = get_prop(state).current_shard
    new_shard = calc_pos_shard(pos)

    # If we switched shards, move over to the new shard
    state = if current_shard != new_shard do
      Logger.debug("Entity #{state.eid} moving from shard #{inspect current_shard} to #{inspect new_shard}")

      # If we just spawned, there will be no shard to leave.
      if current_shard != nil do
        McEx.World.Shard.stop_membership(state.world_id, current_shard, new_shard)
      end
      McEx.World.Shard.Manager.ensure_shard_started(state.world_id, new_shard)
      McEx.World.Shard.start_membership(state.world_id, new_shard, state.eid,
                                        current_shard)
      state = set_prop(state, %{get_prop(state) | current_shard: new_shard})

      # This collects initial entity state from various properties and
      # broadcasts it to the current shard.
      # TODO: I don't think this makes sense to have in here, what property
      # would we put it in?
      {collected, state} = collect_spawn_data(state)
      state = broadcast_shard(state, :entity_enter, collected)

      state
    else
      state
    end

    join_fun = fn shard_pos ->
      McEx.World.Shard.Manager.ensure_shard_started(state.world_id, shard_pos)
      McEx.World.Shard.start_listen(state.world_id, shard_pos)
      McEx.World.Shard.broadcast_members(state.world_id, shard_pos,
                                         :entity_catchup, state.eid, self)
    end
    leave_fun = fn shard_pos ->
      McEx.World.Shard.stop_listen(state.world_id, shard_pos)
    end

    prop = get_prop(state)
    shards = transition_shards(pos, prop.view_distance, prop.shards,
                               join_fun, leave_fun)
    set_prop(state, %{prop | shards: shards})
  end

  @doc """
  This will simply generate a list of all shards the user should be a member
  of in the current position.
  """
  defp get_visible_shards(chunk_pos, chunk_radius) do
    {:chunk, cx, cy} = chunk_pos
    shard_x = Math.floor(cx / @shard_size)
    shard_z = Math.floor(cy / @shard_size)

    shard_radius = Math.ceil(chunk_radius / @shard_size)

    for x <- (shard_x - shard_radius)..(shard_x + shard_radius),
    z <- (shard_z - shard_radius)..(shard_z + shard_radius) do
      {x * @shard_size, z * @shard_size}
    end
  end

  def transition_shards(pos, view_distance, shards_in, join_fun, leave_fun) do
    chunk_pos = Pos.to_chunk(pos)
    shards_join = get_visible_shards(chunk_pos, view_distance)

    # Join
    Enum.reduce(shards_join, shards_in, fn
      element, loaded ->
      if MapSet.member?(loaded, element) do
        loaded
      else
        join_fun.(element)
        MapSet.put(loaded, element)
      end
    end)

    # Leave
    |> Enum.filter(fn element ->
      if Enum.member?(shards_join, element) do
        true
      else
        leave_fun.(element)
        false
      end
    end)
    |> Enum.into(MapSet.new)
  end

  @doc """
  Handles the entity catchup request. Sent by join_leave_shards/1.
  """
  def handle_shard_member_broadcast(pos, :entity_catchup, eid, requester,
                                    state = %{eid: c_eid}) when eid != c_eid do
    # TODO: I don't think this makes sense to have in here, what property
    # would we put it in?
    {collected, state} = collect_spawn_data(state)
    message = {:entity_msg, :info_message, {:catchup_response, collected}}
    send requester, message

    state
  end

  @doc """
  This simply collects data the client needs to spawn a new entity from
  all other properties in the entity.
  """
  defp collect_spawn_data(state) do
    {collected, state} = prop_collect(state, :collect_spawn_data, nil)
    merged = Enum.reduce(collected, %{}, &Map.merge(&1, &2))
    {merged, state}
  end

  # Utilities

  @doc """
  Broadcasts a message to our current shard.
  """
  def broadcast_shard(state, event_id, value) do
    prop = get_prop(state)
    McEx.World.Shard.broadcast(state.world_id, prop.current_shard,
                               event_id, state.eid, value)
    state
  end
  @doc """
  Broadcasts a message to the members of our current shard.
  """
  def broadcast_shard_members(state, event_id, value) do
    prop = get_prop(state)
    McEx.World.Shard.broadcast_members(state.world_id, prop.current_shard,
                                       event_id, state.eid, value)
    state
  end

end
