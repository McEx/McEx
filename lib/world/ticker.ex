defmodule McEx.World.Ticker do
  use GenServer

  def start_link(world_id) do
    GenServer.start_link(__MODULE__, world_id)
  end

  def init(world_id) do
    state = %{
      world_id: world_id,
    }
    :timer.send_after(50, :tick)
    {:ok, state}
  end

  def handle_info(:tick, state) do
    msg = {:entity_msg, :world_event, {:entity_tick, nil}}
    # TODO: Transmit world events on a separate channel?
    McEx.Registry.world_entities_send(state.world_id, msg)

    :timer.send_after(50, :tick)
    {:noreply, state}
  end

end
