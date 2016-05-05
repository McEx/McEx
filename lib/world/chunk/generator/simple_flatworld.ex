defmodule McEx.World.Chunk.Generator.SimpleFlatworld do

  alias McChunk.Chunk

  @behaviour McEx.World.Chunk.Generator

  defp set_layer(section, y, block) do
    Enum.reduce(0..255, section, fn index, section ->
      McChunk.Section.set_block(section, index + y * 256, block * 16)
    end)
  end

  def generate({:chunk, cx, cz}, _opts) do
    section = McChunk.Section.new(palette: [0, 2, 3, 7])
    |> set_layer(0, 7)
    |> set_layer(1, 3)
    |> set_layer(2, 3)
    |> set_layer(3, 2)

    %Chunk{Chunk.new | sections: [section | (for _ <- 0..14, do: nil)]}
  end

end
