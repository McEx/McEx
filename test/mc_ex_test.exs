defmodule McExTest do
  use ExUnit.Case

  test "server player join" do
    world_id = :sw1

    {:ok, supervisor} = McEx.World.Supervisor.start_link(:sw1)
    {:ok, player_pid} = McEx.World.EntitySupervisor.start_entity(
      world_id, McEx.Player,
      %{
        connection: %McProtocol.Acceptor.ProtocolState.Connection{control: self, read: self, write: self},
        identity: %{online: false, name: "Testplayer", uuid: McProtocol.UUID.uuid4},
        entity_id: 100,
      }
    )

    assert_receive {:"$gen_cast", {:write_struct, %McProtocol.Packet.Server.Play.PlayerInfo{}}}

    :ok = Supervisor.stop(supervisor, :normal)
  end
end
