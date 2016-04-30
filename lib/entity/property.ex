defmodule McEx.Entity.Property do

  @callback initial(map) :: any
  @callback handle_client_packet(struct, map) :: map
  @callback handle_world_event(atom, any, map) :: map
  @callback handle_prop_event(atom, any, map) :: map

  defmacro __before_compile__(_env) do
    quote do

      def handle_entity_msg(:world_event, {event_name, value}, state) do
        handle_world_event(event_name, value, state)
      end
      def handle_entity_msg(:shard_broadcast, {pos, eid, event_name, value}, state) do
        handle_shard_broadcast(pos, event_name, eid, value, state)
      end
      def handle_entity_msg(:shard_member_broadcast,
                            {pos, eid, event_name, value}, state) do
        handle_shard_member_broadcast(pos, event_name, eid, value, state)
      end
      def handle_entity_msg(:info_message, data, state) do
        handle_info_message(data, state)
      end
      # TODO: Fix this
      def handle_entity_msg(:client_packet, _packet, state), do: state
      def handle_entity_msg(msg_type, value, state) do
        raise "Entity message type #{inspect msg_type} not handled in property."
      end

      def handle_world_event(_event_name, _value, state), do: state
      def handle_info_message(_data, state), do: state

      def handle_shard_broadcast(_pos, _event_name, _eid, _args, state), do: state
      def handle_shard_member_broadcast(_pos, _event_name, _eid, _args, state),
      do: state

      def handle_prop_event(_, _, state), do: state
      def handle_prop_collect(_, _, state), do: {nil, state}

    end
  end

  defmacro __using__(args) do
    quote do
      @behaviour McEx.Entity.Property
      @before_compile McEx.Entity.Property

      import McEx.Entity.Property, only: [get_prop: 1, set_prop: 2,
                                          prop_broadcast: 3,
                                          prop_collect: 3]
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

  def prop_broadcast(state, event_id, value) do
    Enum.reduce(state.properties, state, fn({mod, _}, state) ->
      apply(mod, :handle_prop_event, [event_id, value, state])
    end)
  end
  def prop_collect(state, event_id, value) do
    Enum.reduce(state.properties, {[], state}, fn({mod, _}, {acc, state}) ->
      {response, state} = apply(mod, :handle_prop_collect, [event_id, value, state])
      case response do
        nil -> {acc, state}
        _ -> {[response | acc], state}
      end
    end)
  end

  @doc """
  This will call the initializers on all properties. It is called by the entity
  process.
  """
  def initial_properties(%{properties: _} = state, props, args \\ %{}) do
    state_props = props |> Enum.map(&{&1, nil}) |> Enum.into(%{})
    state = %{state | properties: state_props}

    props
    |> Enum.reduce(state, fn
      (module, state) -> apply(module, :initial, [args[module], state])
    end)
  end

end
