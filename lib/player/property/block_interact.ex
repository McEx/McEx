defmodule McEx.Player.Property.BlockInteract do
  use McEx.Player.Property

  alias McProtocol.Packet.{Client, Server}

  def initial(_args, state) do
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

  def dig_status(:finish, location, _face, state) do
    #chunk_pos = {:chunk, round(Float.floor(x / 16)), round(Float.floor(z / 16))}
    #chunk_pid = McEx.Registry.chunk_server_pid(state.world_id, chunk_pos)
    #GenServer.call(chunk_pid, {:block_destroy, location})
    McEx.Chunk.set_block(state.world_id, location, 0)
    state
  end
  def dig_status(_, _, _, state), do: state

  def handle_chunk_event(_pos, :set_block, {pos, block}, state) do
    %Server.Play.BlockChange{
      location: pos,
      type: block}
    |> write_client_packet(state)
    state
  end

end
