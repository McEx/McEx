defmodule McEx.Entity do

  @type state :: term
  @type changeset :: McEx.Entity.Properties.Changeset.t

  @callback properties :: %{atom => term}
  @callback init_entity(term, state) :: changeset

  defmacro __using__(args) do
    quote do
      use GenServer
      @behaviour McEx.Entity

      alias McEx.Entity.Properties.Changeset

      import McEx.Entity, only: []

      def init({args}) do
        props = McEx.Entity.Properties.with_base(properties)
        changeset = init_entity(args, props.values)
        props = McEx.Entity.Properties.apply_changes(props, changeset)

        {:ok, props}
      end

      defoverridable []
    end
  end

end
