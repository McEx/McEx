defmodule McEx.EntityMeta do
  alias McEx.DataTypes.Decode
  alias McEx.DataTypes.Encode

  def read(bin, meta \\ []), do: read_r(bin, meta)

  def read_r(<<127::unsigned-integer-1*8, rest::binary>>, meta), do: {meta, rest}
  def read_r(<<key::unsigned-integer-1*5, typ::unsigned-integer-1*3, rest::binary>>, meta) do
    {val, rest} = read_type(typ, rest)
    read_r(rest, [{key, val} | meta])
  end

  def read_type(0, bin), do: Decode.byte(bin)
  def read_type(1, bin), do: Decode.short(bin)
  def read_type(2, bin), do: Decode.int(bin)
  def read_type(3, bin), do: Decode.float(bin)
  def read_type(4, bin), do: Decode.string(bin)
  def read_type(5, bin), do: Decode.slot(bin)
  def read_type(6, bin) do
    {e1, bin} = Decode.int(bin)
    {e2, bin} = Decode.int(bin)
    {e3, bin} = Decode.int(bin)
    {{e1, e2, e3}, bin}
  end
  def read_type(6, bin) do
    {e1, bin} = Decode.float(bin)
    {e2, bin} = Decode.float(bin)
    {e3, bin} = Decode.float(bin)
    {{e1, e2, e3}, bin}
  end

  def write([]), do: <<127::unsigned-integer-1*8>>
end
