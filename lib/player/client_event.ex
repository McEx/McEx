defmodule McEx.Player.ClientEvent do

  def handle({:set_pos, pos}, state) do
    :gproc.send({:world_member, state.world_id}, {:server_event, {:set_pos, state.name, pos}})
    put_in(state.position, pos)
    |> McEx.Player.World.load_chunks
  end

  def handle({:set_look, look}, state) do
    put_in state.look, look
  end

  def handle({:set_on_ground, on_ground}, state) do
    put_in state.on_ground, on_ground
  end

  def handle({:action_digging, mode, {x, _, z} = position, face}, state) do
    if state == :finished do
      chunk_pos = {:chunk, round(Float.floor(x / 16)), round(Float.floor(z / 16))}
      GenServer.cast(:gproc.lookup_pid({:n, :l, {:world, state.world_id, :chunk, chunk_pos}}), {:block_destroy, position})
    end
    state
  end

  def handle({:action_punch_animation}, state) do
    state
  end

  def handle(event, state) do
    IO.inspect event
    state
  end
end
