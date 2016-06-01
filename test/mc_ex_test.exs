defmodule McExTest do
  use ExUnit.Case

  test "server player join" do
    world_id = :sw1

    config = %{
      world_id: world_id,
      world_generator: {McEx.World.Chunk.Generator.SimpleFlatworld, nil},
    }

    self_proc = self

    {:ok, supervisor} = McEx.World.Supervisor.start_link(config)
    {:ok, player_pid} = McEx.World.EntitySupervisor.start_entity(
      world_id, McEx.Player,
      %{
        connection: %McProtocol.Acceptor.ProtocolState.Connection{
          control: self,
          reader: self,
          writer: self,
          write: fn(struct) -> send(self_proc, {:write_struct, struct}) end,
        },
        identity: %{online: false, name: "Testplayer", uuid: McProtocol.UUID.uuid4},
        entity_id: 100,
      }
    )

    assert_receive {:write_struct, %McProtocol.Packet.Server.Play.PlayerInfo{}}

    :ok = Supervisor.stop(supervisor, :normal)
  end
end
