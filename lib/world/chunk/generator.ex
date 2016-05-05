defmodule McEx.World.Chunk.Generator do

  @callback generate({:chunk, integer, integer}, any) :: %McChunk.Chunk{}

end
