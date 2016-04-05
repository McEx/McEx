defmodule McEx.World.WorldManager do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def get_world(name) do
    GenServer.call(__MODULE__, {:get_world, name})
  end

  def init(:ok) do
    {state, pid} = start_world(%{worlds: %{}}, :test)
    {:ok, state}
  end

  defp world_running?(state, name) do
    state.worlds[name] !== nil
  end

  defp start_world(state, name) do
    {:ok, pid} = McEx.World.WorldSupervisor.start_world(name)
    {put_in(state.worlds[name], pid), pid}
  end

  def handle_call({:get_world, :test}, _from, state) do
    {:reply, state.worlds.test, state}
  end
end
