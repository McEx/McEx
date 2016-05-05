defmodule McEx.World.ConfigServer do
  use GenServer

  # Client

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_key(world_id, key) do
    pid = McEx.Registry.world_service_pid(world_id, :config_server)
    GenServer.call(pid, {:get_key, key})
  end

  # Server

  def init(configuration) do
    McEx.Registry.reg_world_service(configuration.world_id, :config_server)
    {:ok, configuration}
  end

  def handle_call({:get_key, key}, _from, state) do
    {:reply, state[key], state}
  end

end
