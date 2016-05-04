defmodule McEx.Util.Math do

  def mod_divisor(x, y) do
    x - y * trunc(Float.floor(x / y))
  end
  def mod_dividend(x, y) do
    x - y * trunc(x / y)
  end

end
