defmodule McEx.World.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, :test_world)
  end

  def init(server_id) do
    children = [
      worker(McEx.Player.KeepAliveSender, [server_id]),
      worker(McEx.EntityIdGenerator, [server_id]),
      supervisor(McEx.Chunk.ChunkSupervisor, [server_id]),
      worker(McEx.Chunk.Manager, [server_id]),
      supervisor(McEx.Player.Supervisor, [server_id]), # TODO: Should be replaced with entity supervisor
      worker(McEx.World.PlayerTracker, [server_id]),
    ]

    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end
