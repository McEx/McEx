defmodule McEx.Util.Math do

  def mod_divisor(x, y) do
    x - y * trunc(Float.floor(x / y))
  end
  def mod_dividend(x, y) do
    x - y * trunc(x / y)
  end

  def floor(num) when num < 0 do
    tr = trunc(num)
    if num - tr == 0, do: tr, else: tr - 1
  end
  def floor(num) do
    trunc(num)
  end

  def ceil(num) when num < 0 do
    trunc(num)
  end
  def ceil(num) do
    tr = trunc(num)
    if num - tr == 0, do: tr, else: tr + 1
  end

end
