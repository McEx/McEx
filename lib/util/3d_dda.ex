defmodule McEx.Util.DDA3D do
  alias McEx.Util.Vec3D

  # Imperative implementation outline, might be useful for someone else:
  # https://gist.github.com/hansihe/bc53b622c4245b706c77caf44aafa840
  # Gist contains the basic implementation, the implementation here is
  # pimped for elixir use.

  @really_small_number 0.0000000000000000000000001

  @doc """
  Takes a point and a vector to trace along from that point.
  Returns a stream that will produce all the blocks along that vector.
  The stream will end when we hit the end of the vector.
  """
  def point_line_segment(start, direction) do
    end_point = Vec3D.add(start, direction) |> Vec3D.floor
    signs = Vec3D.signs(direction)

    point_ray(start, direction)
    |> Stream.transform(true, fn (elem = {voxel, _}, acc) ->
      if acc do
        {[elem], hit_target?(signs, voxel, end_point)}
      else
        {:halt, true}
      end
    end)
  end

  defp hit_target?(signs, pos, target) do
    {xc, yc, zc} = compare_3(signs, pos, target)
    !(xc and yc and zc)
  end

  defp compare_3({xs, ys, zs}, {xp, yp, zp}, {xl, yl, zl}) do
    {compare(xs, xp, xl), compare(ys, yp, yl), compare(zs, zp, zl)}
  end

  def compare(sign, pos, lim) when sign == -1, do: lim >= pos
  def compare(sign, pos, lim) when sign == 0, do: true
  def compare(sign, pos, lim) when sign == 1, do: pos >= lim

  @doc """
  Takes a point and a direction vector.
  Returns a stream that will produce an infinite amount of blocks
  along the ray described by the arguments.
  The consumer is responsible for avoiding infinite iteration.
  """
  def point_ray(start, direction) do
    step = Vec3D.signs(direction)
    direction = denull(direction)
    state = %{
      voxel: Vec3D.floor(start),
      step: step,
      max: voxel_bound(start, direction),
      delta: Vec3D.divi(step, direction),
    }
    Stream.unfold(state, &stream_unfold/1)
  end

  defp stream_unfold(state) do
    {vx, vy, vz} = state.voxel
    {sx, sy, sz} = state.step
    {mx, my, mz} = state.max
    {dx, dy, dz} = state.delta
    if mx < my do
      if mx < mz do
        next_state = %{state | voxel: {vx+sx, vy, vz}, max: {mx+dx, my, mz}}
        {{state.voxel, {-sx, 0, 0}}, next_state}
      else
        next_state = %{state | voxel: {vx, vy, vz+sz}, max: {mx, my, mz+dz}}
        {{state.voxel, {0, 0, -sz}}, next_state}
      end
    else
      if my < mz do
        next_state = %{state | voxel: {vx, vy+sy, vz}, max: {mx, my+dy, mz}}
        {{state.voxel, {0, -sy, 0}}, next_state}
      else
        next_state = %{state | voxel: {vx, vy, vz+sz}, max: {mx, my, mz+dz}}
        {{state.voxel, {0, 0, -sz}}, next_state}
      end
    end
  end

  defp voxel_bound({x, y, z}, {xd, yd, zd}) do
    {
      voxel_bound_element(x, xd),
      voxel_bound_element(y, yd),
      voxel_bound_element(z, zd),
    }
  end

  defp voxel_bound_element(pos, dir) when dir < 0 do
    voxel_bound_element(-pos, -dir)
  end
  defp voxel_bound_element(pos, dir) do
    (1 - mod(pos, 1)) / dir
  end

  defp denull({x, y, z}) do
    {denull_num(x), denull_num(y), denull_num(z)}
  end

  defp denull_num(num) when num == 0, do: @really_small_number
  defp denull_num(num), do: num

  defp mod(x, y), do: x - y * Float.floor(x / y)
  #defp mod(x, y), do: rem((rem(x, y) + y), y)

end
