defmodule McEx.Player.Inventory do
  use GenServer

  # Client

  @type args :: %{
    player_pid: pid,
  }

  @spec start_link(args) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def action(pid, action) do
    GenServer.cast(pid, action)
  end

  # Server

  def init(args) do
    {:ok, nil}
  end

  def handle_cast({:window_close, window_id}, state) do
    {:noreply, state}
  end
  def handle_cast({:window_click, message}, state) do
    {:noreply, state}
  end
  def handle_cast({:window_transaction, window_id, action, accepted}, state) do
    {:noreply, state}
  end
  def handle_cast({:creative_set_slot, slot, id}, state) do
    {:noreply, state}
  end
  def handle_cast({:set_held_item, slot}, state) do
    {:noreply, state}
  end

end
