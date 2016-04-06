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

  # Chunk servers
  def chunk_server_key(world_id, pos), do:
  {:n, :l, {:world_chunks, world_id, pos}}

  def reg_chunk_server(world_id, pos), do:
  :gproc.reg(chunk_server_key(world_id, pos))

  def chunk_server_pid(world_id, pos), do:
  :gproc.lookup_pid(chunk_server_key(world_id, pos))

end
