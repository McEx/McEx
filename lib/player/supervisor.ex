defmodule McEx.Player.Supervisor do
  use Supervisor

  def start_link(world_id) do
    Supervisor.start_link(__MODULE__, world_id)
  end

  def start_player(world_id, connection, player, entity_id) do
    pid = McEx.Registry.world_service_pid(world_id, :player_supervisor)
    Supervisor.start_child(pid, [connection, player, entity_id])
  end

  def init(world_id) do
    McEx.Registry.reg_world_service(world_id, :player_supervisor)
    children = [
      worker(McEx.Player, [world_id], restart: :temporary)
    ]

    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end
end
