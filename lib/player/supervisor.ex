defmodule McEx.Player.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: McEx.Player.Supervisor])
  end

  def start_player(connection, player, entity_id) do
    Supervisor.start_child(McEx.Player.Supervisor, [connection, player, entity_id])
  end

  def init(:ok) do
    spawn_link &McEx.Player.KeepAliveSender.loop/0

    children = [
      worker(McEx.Player, [], restart: :temporary)
    ]

    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end
end
