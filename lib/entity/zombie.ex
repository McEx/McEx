defmodule McEx.Entity.Zombie do
  use GenServer

  def init(args) do
    {:ok,
     %{}}
  end

  def handle_cast({:catchup, connection}, state) do
    {:noreply, state}
  end

end
