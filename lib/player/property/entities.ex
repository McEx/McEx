defmodule McEx.Player.Property.Entities do
  use McEx.Player.Property

  @moduledoc """
  This handles everything related to spawning and despawning entities on the client.

  It depends on:
  * McEx.Entity.Property.Shards
  * McEx.Entity.Property.Position

  It coordinates fairly closely with McEx.Entity.Property.Shards which handles
  shard membership.

  TODO: This is broken at the moment. Entities located in chunks that unload will get
  despawned by the client. This should maintain a registry of entities the client
  knows about along with their positions, so that it can take appropriate action
  when a chunk is unloaded. This will most likely be sending another spawn packet
  for the entities the client despawned in order to prevent a state desync.
  """

  alias McProtocol.Packet.{Client, Server}

  def initial(args, state) do
    set_prop(state, args)
  end

  @doc """
  Handles a new entity entering a shard we are listening to.
  This message is sent by McEx.Entity.Property.Shards.
  """
  def handle_shard_broadcast(pos, :entity_enter, eid, args, state = %{eid: c_eid})
  when eid != c_eid do

    state = spawn_entity(args, state)

    IO.inspect {:enter, pos, eid, args}
    state
  end

  @doc """
  Handles an entity leaving a shard we are listening to.
  This message is sent by McEx.Entity.Property.Shards.
  """
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

  @doc """
  Sends position updates to the client for entities in shards we are listening to.
  This message is sent by McEx.Entity.Property.Position.
  """
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

  @doc """
  This handles the responses we get to the :entity_catchup message sent by
  McEx.Event.Property.Shards.
  It will take care of sending initial data for entities already in a shard when
  enter it.
  This is sent by McEx.Event.Property.Shards.
  """
  def handle_info_message({:catchup_response, data}, state) do
    spawn_entity(data, state)
  end

  defp spawn_entity(descr, state) do
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

      :object ->
        {:pos, x, y, z} = descr.position.pos
        {:look, yaw, pitch} = descr.position.look
        %Server.Play.SpawnEntity{
          entity_id: descr.eid,
          object_uuid: descr.uuid,
          type: descr.entity_type_id,
          x: x, y: y, z: z,
          yaw: trunc(yaw), pitch: trunc(pitch),
          int_field: 0,
          velocity_x: 0,
          velocity_y: 0,
          velocity_z: 0}
        |> write_client_packet(state)
    end

    state
  end

end
