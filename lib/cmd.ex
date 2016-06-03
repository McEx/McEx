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
    fn({_pid, {name, _uuid}}) ->
      name == player
    end)

    if player_pid do
      send player_pid, {:server_event, {:kick, "Kicked by console"}}
      "Kicked player"
    else
      "No player found by that name"
    end
  end

  def get_players(world_id) do
    McEx.Registry.world_players_get(world_id)
  end

  def get_player_pid(world_id, player_name) do
    {player_pid, _} = get_players(world_id)
    |> Enum.find(fn {_pid, player_info} ->
      player_name == player_info.name
    end)
    player_pid
  end

  def player_exec(world_id, player_name, fun) do
    player_pid = get_player_pid(world_id, player_name)
    GenServer.call(player_pid, {:debug_exec, fun})
  end

end
