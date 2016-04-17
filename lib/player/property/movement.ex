defmodule McEx.Player.Property.Movement do
  use McEx.Entity.Property

  alias McProtocol.Packet.{Client, Server}

  def calc_delta_pos({:pos, x, y, z}, {:pos, x0, y0, z0}),
  do: {:rel_pos, x-x0, y-y0, z-z0}
  def empty_delta_pos,
  do: {:rel_pos, 0, 0, 0}

  def initial(state) do
    write_client_packet(state, %Server.Play.SpawnPosition{location: {0, 100, 0}})

    packet = %Server.Play.Position{
      x: 0, y: 100, z: 0,
      yaw: 0, pitch: 0,
      flags: 0,
      teleport_id: 0,
    }
    write_client_packet(state, packet)

    %{
      pos: {:pos, 0, 100, 0},
      look: {:look, 0, 0},
      on_ground: false,
    }
  end

  def handle_client_packet(%Client.Play.Position{} = msg, state) do
    prop = get_prop(state)

    pos = {:pos, msg.x, msg.y, msg.z}
    delta_pos = calc_delta_pos(pos, prop.pos)
    entity_broadcast(state, :move,
                     {pos, delta_pos, prop.look, msg.on_ground})

    prop = %{prop |
      pos: pos,
      on_ground: msg.on_ground,
     }
    set_prop(state, prop)
  end
  def handle_client_packet(%Client.Play.Look{} = msg, state) do
    prop = get_prop(state)

    look = {:look, msg.yaw, msg.pitch}
    entity_broadcast(state, :move,
                     {prop.pos, empty_delta_pos, look, msg.on_ground})
    prop = %{prop |
      look: look,
      on_ground: msg.on_ground,
     }
    set_prop(state, prop)
  end
  def handle_client_packet(%Client.Play.PositionLook{} = msg, state) do
    prop = get_prop(state)

    pos = {:pos, msg.x, msg.y, msg.z}
    delta_pos = calc_delta_pos(pos, prop.pos)
    look = {:look, msg.yaw, msg.pitch}
    entity_broadcast(state, :move, {pos, delta_pos, look, msg.on_ground})

    prop = %{prop |
      pos: pos,
      look: look,
      on_ground: msg.on_ground,
     }
    set_prop(state, prop)
  end
  def handle_client_packet(%Client.Play.Flying{} = msg, state) do
    prop = get_prop(state)

    entity_broadcast(state, :move,
                     {prop.pos, empty_delta_pos, prop.look, msg.on_ground})
    prop = %{prop |
      on_ground: msg.on_ground,
     }
    set_prop(state, prop)
  end

  def delta_pos_to_short({:rel_pos, dx, dy, dz}),
  do: {:rel_pos_short, round(dx*32), round(dy*32), round(dz*32)}
  def deg_to_byte(deg), do: round(deg / 360 * 256)

  # Send movement update of event to the client
  def handle_entity_event(eid, :move, {pos, delta_pos, look, on_ground},
                          state = %{eid: self_eid}) when eid != self_eid do
    {:rel_pos_short, dx, dy, dz} = delta_pos_to_short(delta_pos)
    {:look, yaw, pitch} = look
    packet = %Server.Play.EntityMoveLook{
      entity_id: eid,
      d_x: dx,
      d_y: dy,
      d_z: dz,
      yaw: deg_to_byte(yaw),
      pitch: deg_to_byte(pitch),
      on_ground: on_ground,
    }
    write_client_packet(state, packet)
    state
  end

end
