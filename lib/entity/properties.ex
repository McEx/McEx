defmodule McEx.Entity.Properties do

  defstruct base: %{}, values: %{}

  defmodule Changeset do

    @type t :: term

    def empty do
      []
    end

    def set(changeset, key, value) do
      [{:set, key, value} | changeset]
    end

  end

  def with_base(base) do
    %__MODULE__{
      base: base,
      values: base,
    }
  end

  def apply_changes(attributes, changeset) do
    dynamic = Enum.reduce(changeset, changeset.dynamic, fn
      {{:set, key, value}, s} -> %{s | key => value}
    end)
    %{changeset | dynamic: dynamic}
  end

end
