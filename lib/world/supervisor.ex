defmodule McEx.World.Supervisor do
  use Supervisor

  def start_link(world_id) do
    Supervisor.start_link(__MODULE__, world_id)
  end

  def init(config) do
    world_id = config.world_id
    children = [
      worker(McEx.World.ConfigServer, [config]),
      worker(McEx.EntityIdGenerator, [world_id]),

      supervisor(McEx.Chunk.ChunkSupervisor, [world_id]),
      worker(McEx.Chunk.Manager, [world_id]),

      supervisor(McEx.World.Shard.Supervisor, [world_id]),
      worker(McEx.World.Shard.Manager, [world_id]),

      worker(McEx.Player.KeepAliveSender, [world_id]),
      worker(McEx.World.PlayerTracker, [world_id]),

      supervisor(McEx.World.EntitySupervisor, [world_id]),
      worker(McEx.World.Ticker, [world_id]),
    ]

    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end
