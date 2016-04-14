defmodule McEx.Native.BlockStore do
  require Rustler
  @on_load {:init, 0}

  @behaviour McChunk.BlockStore

  def init do
    :ok = Rustler.load_nif("mc_chunk_native")
  end

  def n_new(_size), do: nil
  def n_decode(_data, _size), do: nil
  def n_encode(_store), do: nil
  def n_get(_store, _bbits, _index), do: nil
  def n_set(_store, _bbits, _index, _val), do: nil

  def new(size), do: n_new(size)

  def decode(data, size) do
    ret = n_decode(data, size)
    data_size = size * 8
    rest_len = byte_size(data) - data_size
    {ret, :erlang.binary_part(data, data_size, rest_len)}
  end

  def encode(store), do: n_encode(store)

  def get(store, bbits, index), do: n_get(store, bbits, index)

  def set(store, bbits, index, value) do
    :ok = n_set(store, bbits, index, value)
    store
  end

end
