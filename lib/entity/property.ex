defmodule McEx.Entity.Property do

  @callback initial :: any
  @callback handle_client_packet(struct, map) :: map
  @callback handle_world_event(atom, any, map) :: map
  @callback handle_entity_event(integer, atom, any, map) :: map

  defmacro __before_compile__(_env) do
    quote do
      def handle_client_packet(_, state), do: state
      def handle_entity_event(_, _, _, state), do: state
      def handle_world_event(_, _, state), do: state
    end
  end

  defmacro __using__(args) do
    quote do
      @behaviour McEx.Entity.Property
      @before_compile McEx.Entity.Property

      import McEx.Entity.Property, only: [get_prop: 1, set_prop: 2,
                                          entity_broadcast: 3,
                                          write_client_packet: 2]
    end
  end

  defmacro get_prop(state) do
    quote do
      unquote(state).properties[unquote(__CALLER__.module)]
    end
  end

  defmacro set_prop(state, value) do
    quote do
      state = unquote(state)
      %{state | properties: %{state.properties | unquote(__CALLER__.module) => unquote(value)}}
    end
  end

  def entity_broadcast(state, event_id, value) do
    McEx.Registry.world_players_send(state.world_id, {:entity_event, state.eid, event_id, value})
  end
  def write_client_packet(state, packet) do
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(state.connection, packet)
  end

end
