defmodule McEx.Math do

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
