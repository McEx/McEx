defmodule McEx.Entity.Item do
  use McEx.Entity.Entity
  use GenServer

  @properties [
    McEx.Entity.Property.Spawn,
    McEx.Entity.Property.Position,
    McEx.Entity.Property.Shards,
    McEx.Entity.Property.Physics,
  ]

  def start_link(world_id, options) do
    GenServer.start_link(__MODULE__, {world_id, options})
  end

  def init({world_id, opts}) do
    uuid = McProtocol.UUID.uuid4
    prop_options = %{
      McEx.Entity.Property.Spawn =>
      %{
        type: :object,
        entity_type_id: 2,
        uuid: uuid,
      },
    }

    state = %{
      eid: opts.entity_id,
      uuid: uuid,
      world_id: world_id,
      properties: %{},
    }
    |> McEx.Entity.Property.initial_properties(@properties, prop_options)

    {:ok, state}
  end

  def handle_info({:entity_msg, type, body}, state) do
    state = Enum.reduce(state.properties, state, fn({mod, _}, state) ->
      apply(mod, :handle_entity_msg, [type, body, state])
    end)
    {:noreply, state}
  end

end
