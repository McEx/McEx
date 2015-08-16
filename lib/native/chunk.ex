defmodule McEx.Native.Chunk do
  @on_load {:init, 0}

  def init do
    #path = :filename.join(:code.priv_dir(:mc_ex), 'libchunk')
    #path = :filename.join(:code.priv_dir(:mc_ex), 'libmcex_chunk')
    path = hd(:filelib.wildcard('rs/target/{debug,release}/libmcex_chunk.*'))
    path = :filename.rootname(path)
    IO.inspect path
    :ok = :erlang.load_nif(path, 0)
  end

  def n_create({_t, _t2}) do
    exit(:nif_library_not_loaded)
  end

  def n_generate(_chunk_handle, _generator, _args) do
    exit(:nif_library_not_loaded)
  end

  def static_atom do
    exit(:nif_library_not_loaded)
  end
  def native_add(_x, _y) do
    exit(:nif_library_not_loaded)
  end
  def tuple_add(_x) do
    exit(:nif_library_not_loaded)
  end
end
