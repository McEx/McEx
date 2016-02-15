defmodule Cmd do
  def player_count do
    player_count = Enum.count(:gproc.lookup_values({:p, :l, :server_player}))
    "There are #{player_count} players online"
  end
  def players do
    Enum.map(:gproc.lookup_values({:p, :l, :server_player}), fn({_pid, {name, uuid}}) -> 
      "#{name} (#{McEx.UUID.hex(uuid)})"
    end)
  end
  def kick(player) do
    {player_pid, _} = Enum.find(:gproc.lookup_values({:p, :l, :server_player}), 
    fn({pid, {name, _uuid}}) ->
      name == player
    end)

    if player_pid do
      send player_pid, {:server_event, {:kick, "Kicked by console"}}
      "Kicked player"
    else
      "No player found by that name"
    end
  end
end
