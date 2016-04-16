defmodule McEx.Util do
  use Bitwise
  require Record

  defmacro __using__(_args) do
    quote do
      require McEx.Util.Pos
      alias McEx.Util.Pos

      require McEx.Util.ChunkPos
      alias McEx.Util.ChunkPos
    end
  end

  defmodule ChunkPos do
    Record.defrecord :chunk, [:x, :z]

    defmacro is_chunk(thing) do
      quote do
        is_tuple(unquote(thing)) and tuple_size(unquote(thing)) == 3 
          and elem(unquote(thing), 0) == :chunk and is_integer(elem(unquote(thing), 1)) and is_integer(elem(unquote(thing), 2))
      end
    end

    def distance({:chunk, x1, z1}, {:chunk, x2, z2}) do
      :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(z2 - z1, 2))
    end
  end
  defmodule Pos do
    Record.defrecord :pos, [:x, :y, :z]

    def to_chunk({:pos, x, _, z}) do
      {:chunk, trunc(x) >>> 4, trunc(z) >>> 4}
    end

    def manhattan_xz_distance({:pos, x1, _, z1}, {:pos, x2, _, z2}) do
      abs(x1 - x2) + abs(z1 - z2)
    end
  end
end
