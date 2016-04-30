defmodule McEx.Player.Property.Movement do
  use McEx.Player.Property

  alias McEx.Entity.Property.{Position}
  alias McProtocol.Packet.{Client, Server}

  @moduledoc """
  Handles movement packets received from the client.

  This simply dispatches to McEx.Entity.Property.Position.

  It depends on:
  * McEx.Entity.Property.Position
  """

  def initial(_args, state) do
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

end
