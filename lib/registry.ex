defmodule McEx.Registry do

  # World service
  def world_service_key(world_id, ident), do:
  {:n, :l, {:world, world_id, ident}}

  def reg_world_service(world_id, ident) do
    :gproc.reg(world_service_key(world_id, ident))
  end

  def dereg_world_service(world_id, ident), do:
  :gproc.unreg(world_service_key(world_id, ident))

  def world_service_pid(world_id, ident), do:
  :gproc.lookup_pid(world_service_key(world_id, ident))

  # Players
  def world_players_key(world_id), do:
  {:p, :l, {:world_players, world_id}}

  def reg_world_player(world_id, val \\ nil), do:
  :gproc.reg(world_players_key(world_id), val)

  # Probably remove this? It SHOULD never be needed.
  def unreg_world_player(world_id), do:
  :gproc.unreg(world_players_key(world_id))

  def world_players_send(world_id, message), do:
  :gproc.send(world_players_key(world_id), message)

  def world_players_get(world_id), do:
  :gproc.lookup_values(world_players_key(world_id))

  # Chunk servers
  def chunk_server_key(world_id, pos), do:
  {:n, :l, {:world_chunks, world_id, pos}}

  def reg_chunk_server(world_id, pos), do:
  :gproc.reg(chunk_server_key(world_id, pos))

  def chunk_server_pid(world_id, pos), do:
  :gproc.lookup_pid(chunk_server_key(world_id, pos))

  # Shards
  def shard_server_key(world_id, pos), do:
  {:n, :l, {:world_shards, world_id, pos}}

  def reg_shard_server(world_id, pos), do:
  :gproc.reg(shard_server_key(world_id, pos))

  def shard_server_pid?(world_id, pos) do
    case :gproc.lookup_pids(shard_server_key(world_id, pos)) do
      [pid] -> {:ok, pid}
      _ -> :noreg
    end
  end
  def shard_server_pid(world_id, pos) do
    :gproc.lookup_pid(shard_server_key(world_id, pos))
  end

  # Shard listeners
  def shard_listener_key(world_id, pos), do:
  {:p, :l, {:shard_listeners, world_id, pos}}

  def reg_shard_listener(world_id, pos), do:
  :gproc.reg(shard_listener_key(world_id, pos))

  def unreg_shard_listener(world_id, pos), do:
  :gproc.unreg(shard_listener_key(world_id, pos))

  def shard_listener_send(world_id, pos, message), do:
  :gproc.send(shard_listener_key(world_id, pos), message)

  # Shard membership
  def shard_member_key(world_id, pos), do:
  {:p, :l, {:shard_members, world_id, pos}}

  def reg_shard_member(world_id, pos), do:
  :gproc.reg(shard_member_key(world_id, pos))

  def unreg_shard_member(world_id, pos), do:
  :gproc.unreg(shard_member_key(world_id, pos))

  def shard_member_send(world_id, pos, message), do:
  :gproc.send(shard_member_key(world_id, pos), message)

end
