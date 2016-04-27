defmodule McEx.Player.Property.Entities do
  use McEx.Entity.Property

  alias McProtocol.Packet.{Client, Server}

  def initial(state) do
    state
  end

  def handle_shard_broadcast(pos, :entity_enter, eid, args, state = %{eid: c_eid})
  when eid != c_eid do

    state = spawn_entity(args, state)

    IO.inspect {:enter, pos, eid, args}
    state
  end

  def handle_shard_broadcast(pos, :entity_exit, eid, args, state = %{eid: c_eid})
  when eid != c_eid do
    IO.inspect {:exit, pos, eid, args}

    %Server.Play.EntityDestroy{
      entity_ids: [eid]}
    |> write_client_packet(state)

    state
  end

  def delta_pos_to_short({:rel_pos, dx, dy, dz}),
  do: {:rel_pos_short, round(dx*4096), round(dy*4096), round(dz*4096)}
  def deg_to_byte(deg), do: round(deg / 360 * 256)

  def handle_shard_broadcast(pos, :entity_move, eid, args, state = %{eid: c_eid})
  when eid != c_eid do
    {pos, delta_pos, look, on_ground} = args
    {:rel_pos_short, dx, dy, dz} = delta_pos_to_short(delta_pos)
    {:look, yaw, pitch} = look

    %Server.Play.EntityMoveLook{
      entity_id: eid,
      d_x: dx,
      d_y: dy,
      d_z: dz,
      yaw: deg_to_byte(yaw),
      pitch: deg_to_byte(pitch),
      on_ground: on_ground}
    |> write_client_packet(state)

    state
  end

  def handle_info_message({:catchup_response, data}, state) do
    spawn_entity(data, state)
  end

  def spawn_entity(descr, state) do
    case descr.type do
      :player ->
        {:pos, x, y, z} = descr.position.pos
        {:look, yaw, pitch} = descr.position.look
        %Server.Play.NamedEntitySpawn{
          entity_id: descr.eid,
          player_uuid: descr.uuid,
          x: x, y: y, z: z,
          yaw: trunc(yaw), pitch: trunc(pitch),
          #yaw: 0, pitch: 0,
          metadata: descr.metadata}
        |> write_client_packet(state)
        %Server.Play.EntityHeadRotation{
          entity_id: descr.eid,
          head_yaw: trunc(yaw)}
        |> write_client_packet(state)
    end

    state
  end

end
