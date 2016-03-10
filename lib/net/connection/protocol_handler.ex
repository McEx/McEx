defmodule McEx.Net.ConnectionNew.ProtocolHandler do
  @callback initial_state :: struct
  def initial_state

  @callback packet_in(struct, struct) :: struct
  def packet_in(packet, state)
end
