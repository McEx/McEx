defmodule McEx.World.AnvilTest do
  use ExUnit.Case, async: true
  alias McEx.World.Anvil

  test "anvil region loading" do
    # {:ok, proc} = Anvil.Region.start_link("./testdata/", {0, 0})

    # GenServer.call(proc, {:read_chunk, {30, 30}})
  end
end
