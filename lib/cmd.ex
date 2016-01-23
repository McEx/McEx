defmodule Cmd do
  def players do
    Enum.map(:gproc.lookup_values({:p, :l, :server_player}), fn({_pid, {name, uuid}}) -> 
      "#{name} (#{McEx.UUID.hex(uuid)})"
    end)
  end
end
