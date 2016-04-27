defmodule McEx.Entity.Property.Shards do
  use McEx.Entity.Property
  use McEx.Util
  require Logger

  alias McEx.Math

  @shard_size 4

  # Property

  def calc_pos_shard(pos) do
    {:chunk, cx, cz} = Pos.to_chunk(pos)
    {Math.floor(cx / @shard_size) * @shard_size,
     Math.floor(cz / @shard_size) * @shard_size,}
  end

  def initial(state) do
    current_shard = calc_pos_shard(
      McEx.Entity.Property.Position.get_position(state).pos)
    Logger.debug("Entity #{state.eid} spawning in shard #{inspect current_shard}")
    McEx.World.Shard.Manager.ensure_shard_started(state.world_id, current_shard)
    McEx.World.Shard.start_membership(state.world_id, current_shard, state.eid)

    prop = %{
      current_shard: current_shard,
      shards: MapSet.new,
    }
    state = set_prop(state, prop)

    {collected, state} = prop_collect(state, :collect_spawn_data, nil)
    merged_collected = Enum.reduce(collected, %{}, &Map.merge(&1, &2))
    state = broadcast_shard(state, :entity_enter, merged_collected)

    state
  end

  def get_visible_shards(chunk_pos, chunk_radius) do
    {:chunk, cx, cy} = chunk_pos
    shard_x = Math.floor(cx / @shard_size)
    shard_z = Math.floor(cy / @shard_size)

    shard_radius = Math.ceil(chunk_radius / @shard_size)

    for x <- (shard_x - shard_radius)..(shard_x + shard_radius),
    z <- (shard_z - shard_radius)..(shard_z + shard_radius) do
      {x * @shard_size, z * @shard_size}
    end
  end

  def listen_shards(pos, view_distance, shards_in, join_fun, leave_fun) do
    chunk_pos = Pos.to_chunk(pos)
    shards_join = get_visible_shards(chunk_pos, 8)

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

  def handle_prop_event(:move, {pos, _, _, _}, state = %{eid: eid}) do
    current_shard = get_prop(state).current_shard
    new_shard = calc_pos_shard(pos)

    # If we switched shards, move over to the new shard
    state = if current_shard != new_shard do
      Logger.debug("Entity #{state.eid} moving from shard #{inspect current_shard} to #{inspect new_shard}")

      McEx.World.Shard.stop_membership(state.world_id, current_shard, new_shard)
      McEx.World.Shard.Manager.ensure_shard_started(state.world_id, new_shard)
      McEx.World.Shard.start_membership(state.world_id, new_shard, state.eid,
                                        current_shard)
      state = set_prop(state, %{get_prop(state) | current_shard: new_shard})

      {collected, state} = prop_collect(state, :collect_spawn_data, nil)
      merged_collected = Enum.reduce(collected, %{}, &Map.merge(&1, &2))
      state = broadcast_shard(state, :entity_enter, merged_collected)

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
    shards = listen_shards(pos, 20, prop.shards, join_fun, leave_fun)
    set_prop(state, %{prop | shards: shards})
  end

  def handle_shard_member_broadcast(pos, :entity_catchup, eid, requester,
                                    state = %{eid: c_eid}) when eid != c_eid do
    IO.inspect {:catchup, requester}
    {collected, state} = prop_collect(state, :collect_spawn_data, nil)
    merged_collected = Enum.reduce(collected, %{}, &Map.merge(&1, &2))
    message = {:entity_msg, :info_message, {:catchup_response, merged_collected}}
    send requester, message

    state
  end

  # Utilities

  def broadcast_shard(state, event_id, value) do
    prop = get_prop(state)
    McEx.World.Shard.broadcast(state.world_id, prop.current_shard,
                               event_id, state.eid, value)
    state
  end
  def broadcast_shard_members(state, event_id, value) do
    prop = get_prop(state)
    McEx.World.Shard.broadcast_members(state.world_id, prop.current_shard,
                                       event_id, state.eid, value)
    state
  end

end
