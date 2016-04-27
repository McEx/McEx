defmodule McEx.Player.Property.Movement do
  use McEx.Entity.Property

  alias McEx.Entity.Property.{Position}
  alias McProtocol.Packet.{Client, Server}

  def initial(state) do
    %{
      pos: {:pos, x, y, z},
      look: {:look, yaw, pitch},
    } = Position.get_position(state)

    %Server.Play.SpawnPosition{location: {x, y, z}}
    |> write_client_packet(state)

    %Server.Play.Position{
      x: x, y: y, z: z,
      yaw: yaw, pitch: pitch,
      flags: 0,
      teleport_id: 0}
    |> write_client_packet(state)

    state
  end

  def handle_client_packet(%Client.Play.Position{} = msg, state) do
    pos = {:pos, msg.x, msg.y, msg.z}
    Position.set_position(state, %{pos: pos, on_ground: msg.on_ground})
  end
  def handle_client_packet(%Client.Play.Look{} = msg, state) do
    look = {:look, msg.yaw, msg.pitch}
    Position.set_position(state, %{look: look, on_ground: msg.on_ground})
  end
  def handle_client_packet(%Client.Play.PositionLook{} = msg, state) do
    pos = {:pos, msg.x, msg.y, msg.z}
    look = {:look, msg.yaw, msg.pitch}
    Position.set_position(state, %{pos: pos, look: look, on_ground: msg.on_ground})
  end
  def handle_client_packet(%Client.Play.Flying{} = msg, state) do
    Position.set_position(state, %{on_ground: msg.on_ground})
  end

  #def delta_pos_to_short({:rel_pos, dx, dy, dz}),
  #do: {:rel_pos_short, round(dx*4096), round(dy*4096), round(dz*4096)}
  #def deg_to_byte(deg), do: round(deg / 360 * 256)

  ## Send movement update of event to the client
  #def handle_entity_event(eid, :entity_move, {pos, delta_pos, look, on_ground},
  #                        state = %{eid: self_eid}) when eid != self_eid do
  #  {:rel_pos_short, dx, dy, dz} = delta_pos_to_short(delta_pos)
  #  {:look, yaw, pitch} = look

  #  %Server.Play.EntityMoveLook{
  #    entity_id: eid,
  #    d_x: dx,
  #    d_y: dy,
  #    d_z: dz,
  #    yaw: deg_to_byte(yaw),
  #    pitch: deg_to_byte(pitch),
  #    on_ground: on_ground}
  #  |> write_client_packet(state)

  #  state
  #end

end
