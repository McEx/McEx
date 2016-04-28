defmodule McEx.Player.Property.ClientSettings do
  use McEx.Player.Property

  @moduledoc """
  This module handles the Client.Play.Settings packet.

  It depends on nothing.
  """

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  defmodule SkinParts do
    defstruct(
      cape: true,
      jacket: true,
      left_sleeve: true,
      right_sleeve: true,
      left_pants: true,
      right_pants: true,
      hat: true)

    def from_bitmask(mask) do
      <<_::1, hat::1, rleg::1, lleg::1, rsleeve::1, lsleeve::1, jacket::1, cape::1>>
      = <<mask::8>>
      %__MODULE__{
        cape: cape == 1,
        jacket: jacket == 1,
        left_sleeve: lsleeve == 1,
        right_sleeve: rsleeve == 1,
        left_pants: lleg == 1,
        right_pants: rleg == 1,
        hat: hat == 1,
      }
    end
  end

  def initial(state) do
    prop = %{
      locale: "en_GB",
      view_distance: 20,
      chat_mode: :enabled,
      chat_colors: true,
      skin_parts: %SkinParts{},
      main_hand: :right,
    }
    set_prop(state, prop)
  end

  def int_chat_mode(0), do: :enabled
  def int_chat_mode(1), do: :commands
  def int_chat_mode(2), do: :hidden

  def int_main_hand(0), do: :left
  def int_main_hand(1), do: :right

  def handle_client_packet(%Client.Play.Settings{} = msg, state) do
    prop = get_prop(state)

    prop =
      %{prop |
        locale: msg.locale,
        view_distance: msg.view_distance,
        chat_mode: int_chat_mode(msg.chat_flags),
        chat_colors: msg.chat_colors,
        skin_parts: SkinParts.from_bitmask(msg.skin_parts),
        main_hand: int_main_hand(msg.main_hand),
       }

    set_prop(state, prop)
  end
end
