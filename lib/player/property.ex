defmodule McEx.Player.Property do

  @moduledoc """
  A player specific variant of an entity property.

  It behaves exactly the same way, except it contains extra boilerplate specific
  for working with the player entity.
  """

  defmacro __before_compile__(_env) do
    quote do

      def handle_entity_msg(:client_packet, packet, state) do
        handle_client_packet(packet, state)
      end

      def handle_client_packet(_packet, state), do: state

    end
  end

  defmacro __using__(_args) do
    quote do
      @before_compile McEx.Player.Property
      use McEx.Entity.Property

      import McEx.Player.Property, only: [write_client_packet: 2]

    end
  end

  def write_client_packet(packet, state) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(state.connection, packet)
  end

end
