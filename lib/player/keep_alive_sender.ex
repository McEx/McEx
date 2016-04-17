defmodule McEx.Player.KeepAliveSender do
  def start_link(world_id) do
    Task.start_link(fn -> loop(world_id) end)
  end

  def loop(world_id) do
    #message = {:server_event, {:keep_alive_send, :rand.uniform(8000), 3}}
    message = {:world_event, :keep_alive_send, {:rand.uniform(8000), 3}}
    McEx.Registry.world_players_send(world_id, message)
    :timer.sleep(10_000)
    loop(world_id)
  end
end
