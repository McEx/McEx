defmodule McEx.Topic do

  def reg_server_player(entity_id, name, uuid) do
    :gproc.reg({:p, :l, :server_player}, {entity_id, name, uuid})
  end
  def send_server_player(message) do
    :gproc.send({:p, :l, :server_player}, message)
  end

  def reg_world(world_id) do
    :gproc.reg({:n, :l, {:world, world_id}})
  end

  def reg_world_chunk(world_id, pos) do
    :gproc.reg({:n, :l, {:world, world_id, :chunk, pos}})
  end

  def reg_world_chunk_manager(world_id) do
    :gproc.reg({:n, :l, {:world_chunk_manager, world_id}})
  end

  def reg_world_player(world_id) do
    :gproc.reg({:p, :l, {:world, world_id, :players}})
  end
  def unreg_world_player(world_id) do
    :gproc.unreg({:p, :l, {:world, world_id, :players}})
  end
  def send_world_player(world_id, message) do
    :gproc.send({:p, :l, {:world, world_id, :players}}, message)
  end

  def reg_world_player_tracker(world_id) do
    :gproc.reg({:n, :l, {:world, world_id, :player_tracker}})
  end
  def get_world_player_tracker_pid(world_id) do
    :gproc.lookup_pid({:n, :l, {:world, world_id, :player_tracker}})
  end

end
