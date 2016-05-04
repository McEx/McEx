defmodule McEx.Util.Vec3D do

  def len({x, y, z}) do
    :math.sqrt(:math.pow(x, 2) + :math.pow(y, 2) + :math.pow(z, 2))
  end

  def signs({x, y, z}) do
    {sign(x), sign(y), sign(z)}
  end
  defp sign(num) when num < 0, do: -1
  defp sign(num) when num == 0, do: 0
  defp sign(num) when num > 0, do: 1

  def norm(vec) do
    divi(vec, len(vec))
  end

  def divi({x0, y0, z0}, {x1, y1, z1}) do
    {x0/x1, y0/y1, z0/z1}
  end
  def divi({x, y, z}, num) do
    {x/num, y/num, z/num}
  end

  def mul({x0, y0, z0}, {x1, y1, z1}) do
    {x0*x1, y0*y1, z0*z1}
  end
  def mul({x, y, z}, num) do
    {x*num, y*num, z*num}
  end

  def add({x0, y0, z0}, {x1, y1, z1}) do
    {x0+x1, y0+y1, z0+z1}
  end
  def sub({x0, y0, z0}, {x1, y1, z1}) do
    {x0-x1, y0-y1, z0-z1}
  end

  def floor({x, y, z}) do
    {trunc(x), trunc(y), trunc(z)}
  end

  def dot({x0, y0, z0}, {x1, y1, z1}) do
    x0 * x1 + y0 * y1 + z0 * z1
  end
  def cross({x0, y0, z0}, {x1, y1, z1}) do
    {y0*z1-z0*y1, z0*x1-x0*z1, x0*y1-y0*x1}
  end

  def nil_vec do
    {0, 0, 0}
  end
  def flip_sign(vec) do
    sub(nil_vec, vec)
  end

  def ray_plane_intersect(ray_origin, ray_direction, plane_origin, plane_normal) do
    ray_direction_norm = norm(ray_direction)
    plane_normal_norm = norm(plane_normal)
    a = dot(sub(plane_origin, ray_origin), plane_normal_norm)
    b = dot(ray_direction_norm, plane_normal_norm)
    time = a / b
    add(ray_origin, mul(ray_direction_norm, time))
  end

  def block_face_plane_point({a, b, c}) when (a + b + c) == 1, do: {1, 1, 1}
  def block_face_plane_point({a, b, c}) when (a + b + c) == -1, do: {0, 0, 0}

  def x({x, _, _}), do: x
  def y({_, y, _}), do: y
  def z({_, _, z}), do: z

end
