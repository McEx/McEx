defmodule McEx.Player.World do
  alias McEx.Player
  alias McEx.Player.PlayerState
  alias McEx.Player.ClientSettings
  use McEx.Util

  def get_chunks_in_view(%PlayerState{position: pos, client_settings: %ClientSettings{view_distance: view_distance}}) do
    {:chunk, chunk_x, chunk_z} = player_chunk = Pos.to_chunk(pos)
    radius = min(view_distance, 20) #TODO: Setting
    
    chunks_in_view = Enum.flat_map((chunk_x - radius)..(chunk_x + radius), fn(a) -> 
          Enum.map((chunk_z - radius)..(chunk_z + radius), fn(b) -> 
            {ChunkPos.distance(player_chunk, {:chunk, 16 * a + 8, 16 * b + 8}), {a, b}} 
          end)
      end)
    Enum.map(Enum.sort(chunks_in_view, fn({dist1, _}, {dist2, _}) -> dist1 <= dist2 end), fn {_, {x, y}} -> {:chunk, x, y} end)
  end

  def load_chunks(%PlayerState{chunk_manager_pid: manager} = state) do
    chunk_load_list = get_chunks_in_view(state)
    loaded_chunks = Enum.reduce(chunk_load_list, state.loaded_chunks, fn element, loaded ->
      if Set.member?(loaded, element) do
        loaded
      else
        McEx.Chunk.Manager.lock_chunk(manager, element, self)
        {:ok, chunk} = McEx.Chunk.Manager.get_chunk(manager, element)
        McEx.Chunk.send_chunk(chunk, state.writer)
        Set.put(loaded, element)
      end
    end)
    loaded_chunks = Enum.into(Enum.filter(loaded_chunks, fn element ->
      if Enum.member?(chunk_load_list, element) do
        true
      else
        McEx.Chunk.Manager.release_chunk(manager, element, self)
        {:chunk, x, z} = element
        Write.write_packet(state.writer, %McEx.Net.Packets.Server.Play.ChunkData{
          chunk_x: x,
          chunk_z: z,
          continuous: true,
          section_mask: 0,
          chunk_data: <<0::8>>})
        false
      end
    end), HashSet.new)

    %{state | loaded_chunks: loaded_chunks}
  end
end
