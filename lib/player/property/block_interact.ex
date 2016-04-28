defmodule McEx.Player.Property.BlockInteract do
  use McEx.Player.Property

  alias McProtocol.Packet.{Client, Server}

  def initial(state) do
    state
  end

  def handle_client_packet(%Client.Play.BlockDig{} = msg, state) do
    case msg.status do
      0 -> dig_status(:start, msg.location, msg.face, state)
      1 -> dig_status(:cancel, msg.location, msg.face, state)
      2 -> dig_status(:finish, msg.location, msg.face, state)
      _ -> state
    end
  end

  def dig_status(:finish, {x, _, z} = location, face, state) do
    chunk_pos = {:chunk, round(Float.floor(x / 16)), round(Float.floor(z / 16))}
    chunk_pid = McEx.Registry.chunk_server_pid(state.world_id, chunk_pos)
    GenServer.call(chunk_pid, {:block_destroy, location})
    state
  end
  def dig_status(_, _, _, state), do: state

  # TODO: This should NOT be a world event.
  # It should ideally be some kind of regional event, possibly
  # unified with entity regions?
  def handle_world_event(:chunk, {:block_destroy, location}, state) do
    %Server.Play.BlockChange{
      location: location,
      type: 0}
    |> write_client_packet(state)
    state
  end

end
