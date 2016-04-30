defmodule McEx.Player.Property.Keepalive do
  use McEx.Player.Property

  alias McProtocol.Packet.{Client, Server}

  def initial(_args, state) do
    prop = %{
      current_nonce: nil,
      missed: 0,
    }
    set_prop(state, prop)
  end

  @mod """
  Event sent by McEx.Player.KeepAliveSender.
  """
  def handle_world_event(:keep_alive_send, {nonce, max_missed}, state) do
    prop = get_prop(state)
    prop =
      case prop.current_nonce do
        nil ->
          %Server.Play.KeepAlive{keep_alive_id: nonce}
          |> write_client_packet(state)
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

  def handle_client_packet(%Client.Play.KeepAlive{keep_alive_id: nonce}, state) do
    prop = get_prop(state)
    prop = if nonce == prop.current_nonce do
      %{prop | current_nonce: nil, missed: 0}
    else
      prop
    end
    set_prop(state, prop)
  end

end
