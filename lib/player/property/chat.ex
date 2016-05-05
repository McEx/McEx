defmodule McEx.Player.Property.Chat do
  use McEx.Player.Property

  alias McProtocol.Packet.{Client, Server}

  def initial(_args, state) do
    state
  end

  def handle_client_packet(%Client.Play.Chat{} = msg, state) do
    msg = {:entity_msg, :world_event,
           {:player_chat_message, {state.identity, msg.message}}}
    # TODO: Transmit world events on a separate channel?
    McEx.Registry.world_players_send(state.world_id, msg)
    state
  end

  def handle_world_event(:player_chat_message, {identity, message}, state) do
    chat_message = %{
      text: "<#{identity.name}> #{message}",
    }

    %Server.Play.Chat{
      position: 0,
      message: Poison.encode!(chat_message)}
    |> write_client_packet(state)

    state
  end

end
