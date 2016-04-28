defmodule McEx.Entity.Item do
  use McEx.Entity.Entity
  use GenServer

  @properties [
    McEx.Entity.Property.Position,
    McEx.Entity.Property.Physics,
  ]

  def start_link(world_id, options) do
    GenServer.start_link(__MODULE__, {world_id, options})
  end

  def init({world_id, opts}) do
    state = %{
      world_id: world_id,
      properties: %{},
    }
    |> McEx.Entity.Property.initial_properties(@properties)

    {:ok, state}
  end

end
