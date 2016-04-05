defmodule McEx.Player.KeepAliveSender do
  def loop do
    message = {:server_event, {:keep_alive_send, :rand.uniform(8000), 3}}
    McEx.Topic.send_server_player(message)
    :timer.sleep(10_000)
    loop
  end
end
