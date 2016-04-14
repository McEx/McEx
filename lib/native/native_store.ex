defmodule McChunk.Native do
  require Rustler
  @on_load {:init, 0}

  def init do
    :ok = Rustler.load_nif("mc_chunk_native")
  end

  def n_new(_size), do: nil
  def n_decode(_data, _size), do: nil
  def n_encode(_store), do: nil
  def n_get(_store, _bbits, _index), do: nil
  def n_set(_store, _bbits, _index, _val), do: nil
end

defmodule McChunk.NativeStore do
  @behaviour McChunk.BlockStore

  # TODO: Handle fails

  def new(size) do
    McChunk.Native.n_new(size)
  end

  def decode(data, size) do
    ret = McChunk.Native.n_decode(data, size)
    data_size = size * 8
    rest_len = byte_size(data) - data_size
    {ret, :erlang.binary_part(data, data_size, rest_len)}
  end

  def encode(store) do
    McChunk.Native.n_encode(store)
  end

  def get(store, bbits, index) do
    McChunk.Native.n_get(store, bbits, index)
  end

  def set(store, bbits, index, value) do
    :ok = McChunk.Native.n_set(store, bbits, index, value)
    store
  end

end
