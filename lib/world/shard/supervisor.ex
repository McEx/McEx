defmodule McEx.World.Shard.Supervisor do
  use Supervisor

  def start_link(world_id) do
    Supervisor.start_link(__MODULE__, world_id)
  end

  def start_shard(world_id, pos) do
    sup_pid = McEx.Registry.world_service_pid(world_id, :shard_supervisor)
    Supervisor.start_child(sup_pid, [pos])
  end

  def init(world_id) do
    McEx.Registry.reg_world_service(world_id, :shard_supervisor)

    children = [
      worker(McEx.World.Shard, [world_id], restart: :transient),
    ]

    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end

end
