defmodule McEx.Player.Property.Chunks do
  use McEx.Entity.Property
  use McEx.Util

  alias McProtocol.Packet.Server

  def initial(state) do
    prop = %{
      last_pos: nil,
      loaded_chunks: MapSet.new,
    }
    set_prop(state, prop)
  end

  def get_chunks_in_view(pos, view_distance) do
    {:chunk, chunk_x, chunk_z} = player_chunk = Pos.to_chunk(pos)
    radius = min(view_distance, Application.get_env(:mc_ex, :view_distance, 8))

    (for x <- (chunk_x - radius)..(chunk_x + radius),
    z <- (chunk_z - radius)..(chunk_z + radius) do
      chunk = {:chunk, x, z}
      {ChunkPos.distance(player_chunk, chunk), chunk}
    end)
    |> Enum.sort(fn
      {dist1, _}, {dist2, _} ->
        dist1 <= dist2
    end)
    |> Enum.map(fn {_, val} -> val end)
  end

  def load_chunk(state, chunk_manager, chunk_pos) do
    McEx.Chunk.Manager.lock_chunk(chunk_manager, chunk_pos, self)
    {:ok, chunk} = McEx.Chunk.Manager.get_chunk(chunk_manager, chunk_pos)
    ret = McEx.Chunk.send_chunk(chunk, state.connection)
    ret
  end
  def unload_chunk(state, chunk_manager, chunk_pos) do
    McEx.Chunk.Manager.release_chunk(chunk_manager, chunk_pos, self)
    {:chunk, x, z} = chunk_pos

    chunk_packet = %Server.Play.UnloadChunk{
      chunk_x: x,
      chunk_z: z,
    }
    McProtocol.Acceptor.ProtocolState.Connection.write_packet(
      state.connection, chunk_packet)
  end

  def load_chunks(state, pos, view_distance, prop) do
    chunk_manager = McEx.Registry.world_service_pid(state.world_id, :chunk_manager)

    chunk_load_list = get_chunks_in_view(pos, view_distance)

    loaded_chunks = Enum.reduce(chunk_load_list, prop.loaded_chunks, fn
      element, loaded ->
      if MapSet.member?(loaded, element) do
        loaded
      else
        load_chunk(state, chunk_manager, element)
        MapSet.put(loaded, element)
      end
    end)

    loaded_chunks = Enum.into(Enum.filter(loaded_chunks, fn
          element ->
          if Enum.member?(chunk_load_list, element) do
            true
          else
            unload_chunk(state, chunk_manager, element)
            false
          end
        end), MapSet.new)

    %{prop | loaded_chunks: loaded_chunks}
  end

  def handle_entity_event(eid, :move, {pos, delta_pos, look, on_ground} = ev,
                          state = %{eid: eid}) do
    prop = get_prop(state)

    # If we have moved more than 8 blocks away from the last chunk load on the
    # xz-plane, we do a chunk load.
    if prop.last_pos == nil or Pos.manhattan_xz_distance(pos, prop.last_pos) > 8 do
      prop = load_chunks(state, pos, 20, prop)
      prop = %{prop | last_pos: pos}
      set_prop(state, prop)
    else
      state
    end

  end
end
