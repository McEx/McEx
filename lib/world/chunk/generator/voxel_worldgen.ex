defmodule McEx.World.Chunk.Generator.VoxelWorldgen do

  alias McChunk.Chunk

  @behaviour McEx.World.Chunk.Generator

  def generate({:chunk, cx, cz}, _opts) do
    data = McEx.Native.Chunk.gen_chunk_raw({cx, cz})
    {sections, ""} = Enum.reduce(0..15, {[], data}, fn sy, {sections, data} ->
      <<section_blocks::binary-size(4096), data::binary>> = data
      section = McChunk.Section.new_from_old(section_blocks)
      {[section | sections], data}
    end)
    %Chunk{Chunk.new | sections: Enum.reverse(sections)}
  end

end
