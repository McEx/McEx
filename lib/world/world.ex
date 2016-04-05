defmodule McEx.World.World do
  # Client

  def start_link(server_id) do
    GenServer.start_link(__MODULE__, server_id)
  end

  def get_chunk_manager(world) do
    GenServer.call(world, :get_chunk_manager)
  end


  # Server
  use GenServer

  def init(world_id) do
    {:ok, pid} = McEx.Chunk.Manager.start_link(world_id)
    {:ok, _} = McEx.World.PlayerTracker.start_link(world_id)
    McEx.Topic.reg_world(world_id)

    {:ok,
     %{
       players: [],
       chunk_manager: pid,
       world_id: world_id
     }
    }
  end

  def handle_call(:get_chunk_manager, _from, state) do
    {:reply, state.chunk_manager, state}
  end
end

