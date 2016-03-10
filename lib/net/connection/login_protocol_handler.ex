defmodule McEx.Net.ConnectionNew.LoginProtocolHandler do
  @behaviour McEx.Net.ConnectionNew.ProtocolHandler

  def packet_in(struct) do
    IO.inspect struct
  end
end
