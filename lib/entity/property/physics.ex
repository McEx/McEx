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
    |> vec3_add({0, -prop.gravity, 0})


    position = McEx.Entity.Property.Position.get_position(state)

    collision_blocks = McEx.Util.DDA3D.point_line_segment(position.pos, velocity)
    |> Enum.take(6)
    |> Enum.map(fn {pos, face} ->
      {pos, get_block(pos, state), face}
    end)
    |> Enum.filter(fn {_, block, _} ->
      block != 0 and block != 144
    end)

    {hit, new_pos} =
      case collision_blocks do
        [] -> {false, Vec3D.add(position.pos, velocity)}
        [{pos, block, face} | _] ->
          face_point = Vec3D.add(pos, Vec3D.block_face_plane_point(face))
          hit_loc = Vec3D.ray_plane_intersect(position.pos, velocity, face_point, face)
          {true, hit_loc}
      end

    state = McEx.Entity.Property.Position.set_position(state, %{pos: new_pos})

    prop = %{
      prop |
      velocity: velocity,
    }

    set_prop(state, prop)
  end

  def get_block(pos, state) do
    {x, y, z} = pos
    chunk_pos = {:chunk, round(Float.floor(x / 16)), round(Float.floor(z / 16))}
    chunk_pid = McEx.Registry.chunk_server_pid(state.world_id, chunk_pos)
    GenServer.call(chunk_pid, {:get_block, pos})
  end

end
