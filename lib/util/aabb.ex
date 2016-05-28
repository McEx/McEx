defmodule McEx.Util.AABB do

  defstruct x: {0, 0}, y: {0, 0}, z: {0, 0}

  def from_points({x0, y0, z0}, {x1, y1, z1}) do
    %__MODULE__{
      x: sort_range_tuple(x0, x1),
      y: sort_range_tuple(y0, y1),
      z: sort_range_tuple(z0, z1),
    }
  end

  def from_pos_size({x0, y0, z0}, {x1, y1, z1}) do
    %__MODULE__{
      x: {x0, x0+x1},
      y: {y0, y0+y1},
      z: {z0, z0+z1},
    }
  end

  def block_aabb({x, y, z}) do
    %__MODULE__{
      x: {x, x+1},
      y: {y, y+1},
      z: {z, z+1},
    }
  end

  def offset(%__MODULE__{x: {x0, x1}, y: {y0, y1}, z: {z0, z1}},
             {xo, yo, zo}) do
    %__MODULE__{
      x: {x0+xo, x1+xo},
      y: {y0+yo, y1+yo},
      z: {z0+zo, z1+zo},
    }
  end

  def expand(%__MODULE__{x: {x0, x1}, y: {y0, y1}, z: {z0, z1}},
             {xe, ye, ze}) do
    %__MODULE__{
      x: (if xe > 0, do: {x0, x1+xe}, else: {x0+xe, x1}),
      y: (if ye > 0, do: {y0, y1+ye}, else: {y0+ye, y1}),
      z: (if ze > 0, do: {z0, z1+ze}, else: {z0+ze, z1}),
    }
  end

  def points(%__MODULE__{x: {x0, x1}, y: {y0, y1}, z: {z0, z1}}) do
    {{x0, y0, z0}, {x1, y1, z1}}
  end
  def min_point(%__MODULE__{x: {x, _}, y: {y, _}, z: {z, _}}), do: {x, y, z}
  def max_point(%__MODULE__{x: {_, x}, y: {_, y}, z: {_, z}}), do: {x, y, z}

  def blocks_in(%__MODULE__{} = aabb) do
    blocks_in_range(aabb.x)
    |> Stream.flat_map(fn x ->
      Stream.map(blocks_in_range(aabb.y), &({x, &1}))
    end)
    |> Stream.flat_map(fn {x, y} ->
      Stream.map(blocks_in_range(aabb.z), &({x, y, &1}))
    end)
  end
  def blocks_in_range({lower, upper}) do
    to_block(lower)..to_block(upper)
  end

  defp to_block(num) when is_integer(num), do: num
  defp to_block(num) when is_float(num), do: trunc(Float.floor(num))

  def clamp_collide_axis(axis, %__MODULE__{} = aabb1, %__MODULE__{} = aabb2, offset) do
    if can_axis_collide?(axis, aabb1, aabb2) do
      aabb1_axis = Map.fetch!(aabb1, axis)
      aabb2_axis = Map.fetch!(aabb2, axis)
      cond do
        offset > 0 and range_lte?(aabb1_axis, aabb2_axis) ->
          delta = range_diff_gt(aabb1_axis, aabb2_axis)
          if delta < offset, do: delta, else: offset
        offset < 0 and range_gte?(aabb1_axis, aabb2_axis) ->
          delta = range_diff_lt(aabb1_axis, aabb2_axis)
          if delta > offset, do: delta, else: offset
        true ->
          offset
      end
    else
      offset
    end
  end

  def can_axis_collide?(:x, %__MODULE__{} = bb1, %__MODULE__{} = bb2), do:
  range_intersect?(bb1.y, bb2.y) and range_intersect?(bb1.z, bb2.z)
  def can_axis_collide?(:y, %__MODULE__{} = bb1, %__MODULE__{} = bb2), do:
  range_intersect?(bb1.x, bb2.x) and range_intersect?(bb1.z, bb2.z)
  def can_axis_collide?(:z, %__MODULE__{} = bb1, %__MODULE__{} = bb2), do:
  range_intersect?(bb1.x, bb2.x) and range_intersect?(bb1.y, bb2.y)

  def range_intersect?({a0, a1}, {b0, b1}) when b1 > a0 and b0 < a1, do: true
  def range_intersect?(_, _), do: false

  def range_within?({s, e}, p) when p > s and e < p, do: true
  def range_within?(_, _), do: false

  def range_lt?({lr, _}, {_, hr}) when hr < lr, do: true
  def range_lt?(_, _), do: false
  def range_gt?({_, lr}, {hr, _}) when hr > lr, do: true
  def range_gt?(_, _), do: false
  def range_lte?({lr, _}, {_, hr}) when hr <= lr, do: true
  def range_lte?(_, _), do: false
  def range_gte?({_, lr}, {hr, _}) when hr >= lr, do: true
  def range_gte?(_, _), do: false

  def range_diff_gt({a, _}, {_, b}), do: a - b
  def range_diff_lt({_, a}, {b, _}), do: a - b

  def sort_range_tuple(p0, p1) when p0 < p1, do: {p0, p1}
  def sort_range_tuple(p0, p1), do: {p1, p0}

end
