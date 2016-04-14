defmodule McEx.Player.World do
  alias McEx.Player
  alias McEx.Player.PlayerState
  alias McEx.Player.ClientSettings
  alias McEx.Net.Connection.Write
  alias McProtocol.Packet
  use McEx.Util

  def get_chunks_in_view(%PlayerState{position: pos, client_settings: %ClientSettings{view_distance: view_distance}}) do
    {:chunk, chunk_x, chunk_z} = player_chunk = Pos.to_chunk(pos)
    radius = min(view_distance, Application.get_env(:mc_ex, :view_distance, 8))

    (for x <- (chunk_x - radius)..(chunk_x + radius),
         z <- (chunk_z - radius)..(chunk_z + radius),
         do: {ChunkPos.distance(player_chunk, {:chunk, 16 * x + 8, 16 * z + 8}), {x, z}})
    |> Enum.sort(fn({dist1, _}, {dist2, _}) -> dist1 <= dist2 end)
    |> Enum.map(fn {_, {x, z}} -> {:chunk, x, z} end)
  end

  def load_chunks(%PlayerState{} = state) do
    chunk_manager = McEx.Registry.world_service_pid(state.world_id, :chunk_manager)

    chunk_load_list = get_chunks_in_view(state)
    loaded_chunks = Enum.reduce(chunk_load_list, state.loaded_chunks, fn element, loaded ->
      if Set.member?(loaded, element) do
        loaded
      else
        McEx.Chunk.Manager.lock_chunk(chunk_manager, element, self)
        {:ok, chunk} = McEx.Chunk.Manager.get_chunk(chunk_manager, element)
        McEx.Chunk.send_chunk(chunk, state.connection)
        Set.put(loaded, element)
      end
    end)
    loaded_chunks = Enum.into(Enum.filter(loaded_chunks, fn element ->
      if Enum.member?(chunk_load_list, element) do
        true
      else
        McEx.Chunk.Manager.release_chunk(chunk_manager, element, self)
        {:chunk, x, z} = element

        chunk_packet = %Packet.Server.Play.MapChunk{
          x: x,
          z: z,
          ground_up: true,
          bit_map: 0,
          chunk_data: <<0::8>>
        }
        McProtocol.Acceptor.ProtocolState.Connection.write_packet(state.connection, chunk_packet)

        false
      end
    end), HashSet.new)

    %{state | loaded_chunks: loaded_chunks}
  end
end
