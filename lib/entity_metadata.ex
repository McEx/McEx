defmodule McEx.EntityMeta.Util do
  defmacro metatype(num, atom) do
    quote do
      def type_idx(unquote(atom)), do: unquote(num)
      def idx_type(unquote(num)), do: unquote(atom)
    end
  end
  defmacro simple_reader(typ, fun) do
    quote do
      def read_type(unquote(typ), bin) do
        {val, bin} = unquote(fun)(bin)
        {{unquote(typ), val}, bin}
      end
    end
  end
end

defmodule McEx.EntityMeta do
  alias McEx.DataTypes.Decode
  alias McEx.DataTypes.Encode
  import McEx.EntityMeta.Util

  metatype(0, :byte)
  metatype(1, :short)
  metatype(2, :int)
  metatype(3, :float)
  metatype(4, :string)
  metatype(5, :slot)
  metatype(6, :pos)
  metatype(7, :rot)

  def read(bin, meta \\ []), do: read_r(bin, meta)
  def read_r(<<127::unsigned-integer-1*8, rest::binary>>, meta), do: {meta, rest}
  def read_r(<<key::unsigned-integer-1*5, typ::unsigned-integer-1*3, rest::binary>>, meta) do
    {val, rest} = read_type(typ, rest)
    read_r(rest, [{key, val} | meta])
  end

  def read_type(typ, bin) when is_integer(typ), do: read_type(idx_type(typ), bin)
  def read_type(:pos, bin) do
    {e1, bin} = Decode.int(bin)
    {e2, bin} = Decode.int(bin)
    {e3, bin} = Decode.int(bin)
    {{e1, e2, e3}, bin}
  end
  def read_type(:rot, bin) do
    {e1, bin} = Decode.float(bin)
    {e2, bin} = Decode.float(bin)
    {e3, bin} = Decode.float(bin)
    {{e1, e2, e3}, bin}
  end
  def read_type(typ, bin) when is_atom(typ) do
    type_idx(typ)
    {val, bin} = apply(Decode, typ, [bin])
    {{typ, val}, bin}
  end

  # tail recursion you idiot
  def write([]), do: <<127::unsigned-integer-1*8>>
  def write([item | rest]) do
    write_type(item) <> write(rest)
  end

  def write_type({key, typ, val}) when is_integer(key) do
    idx = type_idx(typ)
    <<key::unsigned-integer-1*5, idx::unsigned-integer-1*3, encode_type(typ, val)::binary>>
  end

  def encode_type(:pos, {e1, e2, e3}) do
    Encode.int(e1) <> Encode.int(e2) <> Encode.int(e3)
  end
  def encode_type(:rot, {e1, e2, e3}) do
    Encode.float(e1) <> Encode.float(e2) <> Encode.float(e3)
  end
  def encode_type(typ, val) when is_atom(typ), do: apply(Encode, typ, [val])

end

defmodule McEx.EntityMeta.Entity do
  defp t(true), do: 1
  defp t(false), do: 0

  def status({on_fire, crouched, sprinting, using, invisible}) do
    <<num::integer-1*8>> = <<0::integer-1*3, t(invisible)::integer-1*1, t(using)::integer-1*1, t(sprinting)::integer-1*1, 
        t(crouched)::integer-1*1, t(on_fire)::integer-1*1>>
    {0, :byte, num}
  end
end
