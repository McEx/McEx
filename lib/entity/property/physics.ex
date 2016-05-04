defmodule McEx.Entity.Property.Physics do
  use McEx.Entity.Property

  alias McEx.Util.Vec3D

  def vec3_mul({x0, y0, z0}, {x1, y1, z1}), do: {x0*x1, y0*y1, z0*z1}
  def vec3_mul({x0, y0, z0}, fac), do: {x0*fac, y0*fac, z0*fac}
  def vec3_sub({x0, y0, z0}, {x1, y1, z1}), do: {x0-x1, y0-y1, z0-z1}
  def vec3_add({x0, y0, z0}, {x1, y1, z1}), do: {x0+x1, y0+y1, z0+z1}

  def initial(args, state) do
    prop = %{
      gravity: args.gravity,
      drag: args.drag,
      velocity: Map.get(args, :velocity, {0, 0, 0}),
    }
    set_prop(state, prop)
  end

  def handle_world_event(:entity_tick, _, state) do
    prop = get_prop(state)

    velocity = prop.velocity
    velocity = velocity
    |> vec3_sub(vec3_mul(velocity, prop.drag))
    |> vec3_add({0, prop.gravity, 0})


    pos = McEx.Entity.Property.Position.get_position(state)
    {xv, yv, zv} = velocity
    {:pos, xp, yp, zp} = pos.pos

    collision_blocks = McEx.Util.DDA3D.point_line_segment({xp, yp, zp}, velocity)
    |> Enum.take(6)
    |> Enum.map(fn {pos = {x, y, z}, face} ->
      {pos, get_block({:pos, x, y, z}, state), face}
    end)
    |> Enum.filter(fn {_, block, _} ->
      block != 0
    end)
    {hit, collision} =
      case collision_blocks do
        [] -> {false, Vec3D.add({xp, yp, zp}, velocity)}
        [{pos, block, face} | _] ->
          face_point = Vec3D.add(pos, Vec3D.block_face_plane_point(face))
          hit_loc = Vec3D.ray_plane_intersect({xp, yp, zp}, velocity, face_point, face)
          {true, hit_loc}
      end

    {col_x, col_y, col_z} = collision
    new_pos = {:pos, col_x, col_y, col_z}
    IO.inspect new_pos

    #new_pos = if yp-yv < 60 do
    #  {:pos, xp-xv, 60, zp-zv}
    #else
    #  {:pos, xp-xv, yp-yv, zp-zv}
    #end
    state = McEx.Entity.Property.Position.set_position(state, %{pos: new_pos})

    prop = %{
      prop |
      velocity: velocity,
    }

    set_prop(state, prop)
  end

  def get_block(pos, state) do
    {:pos, x, y, z} = pos
    chunk_pos = {:chunk, round(Float.floor(x / 16)), round(Float.floor(z / 16))}
    chunk_pid = McEx.Registry.chunk_server_pid(state.world_id, chunk_pos)
    GenServer.call(chunk_pid, {:get_block, pos})
  end

end
