defmodule McEx.World.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, nil)
  end

  def init(server_id) do
    children = [
      #worker(McEx.Entity.EntityIdGenerator, [server_id]),
      supervisor(McEx.Chunk.ChunkSupervisor, []),
      #worker(McEx.World.World, [server_id]),
      supervisor(McEx.World.WorldSupervisor, []),
      worker(McEx.World.WorldManager, []),
    ]

    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end
