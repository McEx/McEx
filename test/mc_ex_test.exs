defmodule McExTest do
  use ExUnit.Case

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "server player join" do
    world_id = :sw1

    {:ok, supervisor} = McEx.World.Supervisor.start_link(:sw1)
    {:ok, player_pid} = McEx.World.EntitySupervisor.start_entity(
      world_id, McEx.Player,
      %{
        connection: %McProtocol.Acceptor.ProtocolState.Connection{control: self},
        identity: %{online: false, name: "Testplayer", uuid: McProtocol.UUID.uuid4},
        entity_id: 100,
      }
    )
    :ok = Supervisor.stop(supervisor, :normal)
  end
end
