defmodule McEx.World.EntitySupervisor.Spawner do

  def start_link(world_id, module, options) do
    apply(module, :start_link, [world_id, options])
  end

end

defmodule McEx.World.EntitySupervisor do
  use Supervisor

  def start_link(world_id) do
    ret = Supervisor.start_link(__MODULE__, world_id)
    ret
  end

  def start_entity(world_id, module, options) do
    pid = McEx.Registry.world_service_pid(world_id, :entity_supervisor)
    options = if options[:entity_id] == nil do
      Map.put(options, :entity_id, McEx.EntityIdGenerator.get_id(world_id))
    else
      options
    end
    Supervisor.start_child(pid, [module, options])
  end

  def init(world_id) do
    McEx.Registry.reg_world_service(world_id, :entity_supervisor)

    children = [
      worker(McEx.World.EntitySupervisor.Spawner, [world_id], restart: :temporary),
    ]

    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end

end
