defmodule McEx.Native.Chunk.TestingWoo do
  defstruct testing: 12, another_test: "Testing!!"
end

defmodule McEx.Native.Chunk do
  @on_load {:init, 0}

  def init do
    #path = :filename.join(:code.priv_dir(:mc_ex), 'libchunk')
    #path = :filename.join(:code.priv_dir(:mc_ex), 'libmcex_chunk')
    path = hd(:filelib.wildcard('rs/target/{debug,release}/libmcex_chunk.*'))
    path = :filename.rootname(path)
    #IO.inspect path
    :ok = :erlang.load_nif(path, 0)
  end

  def n_create, do: exit(:nif_library_not_loaded)
  def create, do: n_create

  def n_assemble_packet(_chunk_res, {_skylight, _entire_chunk, _bitmask}), do: exit(:nif_library_not_loaded)
  def assemble_packet(chunk_res, meta), do: n_assemble_packet(chunk_res, meta)
end
