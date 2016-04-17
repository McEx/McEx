defmodule McEx.Player.Property.Keepalive do
  use McEx.Entity.Property

  alias McProtocol.Packet.{Client, Server}

  def initial do
    %{
      current_nonce: nil,
      missed: 0,
    }
  end

  def handle_world_event(:keep_alive_send, {nonce, max_missed}, state) do
    prop = get_prop(state)
    prop = case prop.current_nonce do
      nil ->
        write_client_packet(state, %Server.Play.KeepAlive{keep_alive_id: nonce})
        prop
      _ ->
        if prop.missed > max_missed do
          # TODO: Proper kick
          raise "Timeout"
        else
          %{prop | missed: prop.missed + 1}
        end
    end
    set_prop(state, prop)
  end

  def handle_player_packet(%Client.Play.KeepAlive{keep_alive_id: nonce}, state) do
    prop = get_prop(state)
    prop = if nonce = prop.current_nonce do
      %{prop | current_nonce: nil, missed: 0}
    else
      prop
    end
  end

end
