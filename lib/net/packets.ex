defmodule McEx.Net.Packets.Macros do
  defmodule End do
    defmacro __using__(_opts) do
      quote do
        def read_packet_id(data, mode, id) do
          throw "Cannot read packet id #{id} in mode #{mode}"
        end
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import McEx.Net.Packets.Macros

      def read_packet(data, mode) do
        {id, data} = McEx.DataTypes.Decode.varint(data)
        read_packet_id(data, mode, id)
      end

      def write_packet(struct, mode, name) do
        <<McEx.DataTypes.Encode.varint(packet_id(mode, name))::binary, write_packet_name(struct, mode, name)::binary>>
      end
      def write_packet(%{} = struct) do
        <<McEx.DataTypes.Encode.varint(packet_id(struct))::binary, write_packet_type(struct)::binary>>
      end
    end
  end

  defmacro packet(mode, id, name, fields) do
    require Mix.Utils

    mode_mod = Mix.Utils.camelize(Atom.to_string(mode))
    name_mod = Mix.Utils.camelize(Atom.to_string(name))
    mod = "#{Atom.to_string(__CALLER__.module)}.#{mode_mod}.#{name_mod}"
    |> String.to_atom

    quote do
      defmodule unquote(mod) do
        defstruct unquote(Keyword.keys(fields))
        def mode, do: unquote(mode)
        def name, do: unquote(name)
        def id, do: unquote(id)
      end
      def read_packet_id(data, unquote(mode), unquote(id)) do
        {decoded, _} = McEx.Net.Packets.Macros.decode_packet(data, %unquote(mod){}, unquote(fields))
        Map.put(decoded, :__struct__, unquote(mod))
      end
      def write_packet_name(struct, unquote(mode), unquote(name)) do
        McEx.Net.Packets.Macros.encode_packet(struct, unquote(fields))
      end
      def write_packet_type(%unquote(mod){} = struct) do
        McEx.Net.Packets.Macros.encode_packet(struct, unquote(fields))
      end
      def packet_name(unquote(mode), unquote(id)), do: unquote(name)
      def packet_name(%unquote(mod){}), do: unquote(name)
      def packet_id(unquote(mode), unquote(name)), do: unquote(id)
      def packet_id(%unquote(mod){}), do: unquote(id)
    end
  end

  defmacro exists_if(conditional_field, value, type) do
    quote do
      {
        fn struct, name -> #encode
          case Map.get(struct, unquote(conditional_field)) do
            unquote(value) -> McEx.Net.Packets.Macros.encode_type(struct, name, unquote(type)) #write
            _ -> <<>>
          end
        end,
        fn data, struct, name -> #decode
          case Map.get(struct, unquote(conditional_field)) do
            unquote(value) -> McEx.Net.Packets.Macros.decode_type(data, struct, name, unquote(type)) #read
            _ -> {nil, data}
          end
        end
      }
    end
  end

  defmacro array(length_field, fields) do
    quote do
      {
        fn struct, name -> #encode
          items = Map.fetch!(struct, name)
          len = length(items)
          ^len = Map.fetch!(struct, unquote(length_field))
          McEx.Net.Packets.Macros.encode_array(items, unquote(fields))
        end,
        fn data, struct, name -> #decode
          len = Map.fetch!(struct, unquote(length_field))
          McEx.Net.Packets.Macros.decode_array(data, unquote(fields), [], len)
        end
      }
    end
  end
  
  def encode_array([item | rest], fields) do
    <<encode_packet(item, fields)::binary, encode_array(rest, fields)::binary>>
  end
  def encode_array([], _), do: <<>>
  def decode_array(data, _, array, 0), do: {array, data}
  def decode_array(data, fields, array, num) do
    {decoded, data} = decode_packet(data, %{}, fields)
    decode_array(data, fields, array ++ [decoded], num-1)
  end

  def decode_packet(data, struct, [{name, type} | fields]) do
    {result, data} = decode_type(data, struct, name, type)
    decode_packet(data, Map.put(struct, name, result), fields)
  end
  def decode_packet(data, struct, []) do
    {struct, data}
  end

  def decode_type(data, struct, name, {_, decode_fun}) when is_function(decode_fun, 3) do
    decode_fun.(data, struct, name)
  end
  def decode_type(data, struct, _, {type, args}) when is_atom(type) and is_list(args) do
    apply(McEx.DataTypes.Decode, type, [data, struct] ++ args)
  end
  def decode_type(data, struct, _, type) when is_atom(type) do
    apply(McEx.DataTypes.Decode, type, [data])
  end

  def encode_packet(struct, [{name, type} | fields]) do
    <<encode_type(struct, name, type)::binary, encode_packet(struct, fields)::binary>>
  end
  def encode_packet(_, []) do
    <<>>
  end

  def encode_type(struct, name, {encode_fun, _}) when is_function(encode_fun, 2) do
    encode_fun.(struct, name)
  end
  def encode_type(struct, name, {type, args}) when is_atom(type) and is_list(args) do
    value = Map.fetch!(struct, name)
    apply(McEx.DataTypes.Encode, type, [value, struct] ++ args)
  end
  def encode_type(struct, name, type) when is_atom(type) do
    value = Map.fetch!(struct, name)
    apply(McEx.DataTypes.Encode, type, [value])
  end
end

defmodule McEx.Net.Packets.Client do #Serverbound
  use McEx.Net.Packets.Macros

  packet :init, 0x00, :handshake,
    protocol_version: :varint, 
    server_address: :string,
    server_port: :u_short,
    next_mode: :varint

  packet :status, 0x00, :request, []
  packet :status, 0x01, :ping, payload: :long

  packet :login, 0x00, :login_start,
    name: :string
  packet :login, 0x01, :encryption_response,
    shared_secret: :varint_length_binary,
    verify_token: :varint_length_binary

  packet :play, 0x00, :keep_alive,
    nonce: :varint
  packet :play, 0x01, :chat_message,
    message: :string
  packet :play, 0x02, :use_entity,
    target: :varint,
    type: :varing,
    target_x: exists_if(:type, 2, :float),
    target_y: exists_if(:type, 2, :float),
    target_z: exists_if(:type, 2, :float)
  packet :play, 0x03, :player_ground,
    on_ground: :bool
  packet :play, 0x04, :player_position,
    x: :double,
    y: :double,
    z: :double,
    on_ground: :bool
  packet :play, 0x05, :player_look,
    yaw: :float,
    pitch: :float,
    on_ground: :bool
  packet :play, 0x06, :player_position_look,
    x: :double,
    y: :double,
    z: :double,
    yaw: :float,
    pitch: :float,
    on_ground: :bool
  packet :play, 0x07, :player_digging,
    status: :byte,
    location: :position,
    face: :byte
  packet :play, 0x08, :player_block_placement,
    location: :position,
    face: :byte,
    held_item: :slot,
    cursor_x: :byte,
    cursor_y: :byte,
    cursor_z: :byte
  packet :play, 0x09, :held_item_change,
    slot: :short
  packet :play, 0x0a, :animation, []
  packet :play, 0x0b, :entity_action,
    entity_id: :varint,
    action_id: :varint,
    jump_boost: :varint
  packet :play, 0x0c, :steer_vehicle,
    sideways: :float,
    forward: :float,
    flags: :byte
  packet :play, 0x0d, :close_window,
    window_id: :u_byte
  packet :play, 0x0e, :click_window,
    window_id: :u_byte,
    slot: :short,
    button: :byte,
    action_number: :short,
    mode: :byte,
    clicked_item: :slot
  packet :play, 0x0f, :confirm_transaction, #TODO: Figure out why this is sent serverbound..
    window_id: :u_byte,
    action_number: :short,
    accepted: :boolean
  packet :play, 0x10, :creative_inventory_action,
    slot: :short,
    item: :slot
  packet :play, 0x11, :enchant_item,
    window_id: :byte,
    enchantment: :byte
  packet :play, 0x12, :update_sign,
    location: :position,
    line_1: :chat,
    line_2: :chat,
    line_3: :chat,
    line_4: :chat
  packet :play, 0x13, :player_abilities,
    flags: :byte_flags,
    flying_speed: :float,
    walking_speed: :float
  packet :play, 0x14, :tab_complete,
    text: :string,
    has_look: :bool,
    block_look: exists_if(:has_look, true, :position)
  packet :play, 0x15, :client_settings,
    locale: :string,
    view_distance: :byte,
    chat_mode: :byte,
    chat_colors: :bool,
    skin_parts: :byte_flags
  packet :play, 0x16, :client_status,
    action_id: :varint #0: perform respawn, 1: request stats, 2: taking inventory achivement
  packet :play, 0x17, :plugin_message,
    channel: :string,
    data: :byte_array_rest
  packet :play, 0x18, :spectate,
    target_player: :uuid
  packet :play, 0x19, :resource_pack_status,
    hash: :string,
    result: :varint

  use McEx.Net.Packets.Macros.End
end

defmodule McEx.Net.Packets.Server do #Clientbound
  use McEx.Net.Packets.Macros

  packet :status, 0x00, :response, response: :string
  packet :status, 0x01, :pong, payload: :long

  packet :login, 0x00, :disconnect, reason: :chat
  packet :login, 0x01, :encryption_request, 
    server_id: :string,
    public_key: :varint_length_binary,
    verify_token: :varint_length_binary
  packet :login, 0x02, :login_success,
    uuid: :string,
    username: :string
  packet :login, 0x03, :set_compression,
    threshold: :varint

  packet :play, 0x00, :keep_alive,
    nonce: :varint
  packet :play, 0x01, :join_game,
    entity_id: :int,
    gamemode: :u_byte,
    dimension: :byte,
    difficulty: :u_byte,
    max_players: :u_byte,
    level_type: :string,
    reduced_debug_info: :bool
  packet :play, 0x02, :chat_message,
    data: :chat,
    position: :byte
  packet :play, 0x03, :time_update,
    world_age: :long,
    time_of_day: :long
  packet :play, 0x04, :entity_equipment,
    entity_id: :varint,
    slot: :short,
    item: :slot
  packet :play, 0x05, :spawn_position,
    location: :position
  packet :play, 0x06, :update_health,
    health: :float,
    food: :varint,
    food_saturation: :float
  packet :play, 0x07, :respawn,
    dimension: :int,
    difficulty: :u_byte,
    gamemode: :u_byte,
    level_type: :string
  packet :play, 0x08, :player_position_look,
    x: :double,
    y: :double,
    z: :double,
    yaw: :float,
    pitch: :float,
    flags: :byte #X, Y, Z, X_ROT, Y_ROT. If set, update is relative.
  packet :play, 0x09, :held_item_change,
    slot: :byte
  packet :play, 0x0a, :use_bed,
    entity_id: :varint,
    location: :position
  packet :play, 0x0b, :animation,
    entity_id: :varint,
    animation: :u_byte
  packet :play, 0x0c, :spawn_player,
    entity_id: :varint,
    player_uuid: :uuid,
    x: :int,
    y: :int,
    z: :int,
    yaw: :angle,
    pitch: :angle,
    current_item: :short,
    metadata: :metadata
  packet :play, 0x0d, :collect_item,
    collected_id: :varint, #(entity ids)
    collector_id: :varint
  packet :play, 0x0e, :spawn_object,
    entity_id: :varint,
    type: :byte,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    yaw: :angle,
    pitch: :angle,
    data: :object_data
  packet :play, 0x0f, :spawn_mob,
    entity_id: :varint,
    type: :byte,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    yaw: :angle,
    pitch: :angle,
    head_pitch: :angle,
    velocity_x: :short,
    velocity_y: :short,
    velocity_z: :short,
    metadata: :metadata
  packet :play, 0x10, :spawn_painting,
    entity_id: :varint,
    title: :string,
    location: :position,
    direction: :u_byte
  packet :play, 0x11, :spawn_experience_orb,
    entity_id: :varint,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    count: :short
  packet :play, 0x12, :entity_velocity,
    entity_id: :varint,
    velocity_x: :short,
    velocity_y: :short,
    velocity_z: :short
  #TODO: Packet 0x13
  packet :play, 0x14, :entity, #Entity "ping" packet
    entity_id: :varint
  packet :play, 0x15, :entity_relative_move,
    entity_id: :varint,
    delta_x: :byte,
    delta_y: :byte,
    delta_z: :byte,
    on_ground: :bool
  packet :play, 0x16, :entity_look,
    entity_id: :varint,
    yaw: :angle, #not delta
    pitch: :angle, #^
    on_ground: :bool
  packet :play, 0x17, :entity_look_relative_move,
    entity_id: :varint,
    delta_x: :fixed_point_byte,
    delta_y: :fixed_point_byte,
    delta_z: :fixed_point_byte,
    yaw: :angle, #not delta
    pitch: :angle, #^
    on_ground: :bool
  packet :play, 0x18, :entity_teleport,
    entity_id: :varint,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    yaw: :angle,
    pitch: :angle,
    on_ground: :bool
  packet :play, 0x19, :entity_head_look,
    entity_id: :varint,
    head_yaw: :angle #not delta
  packet :play, 0x1a, :entity_status,
    entity_id: :int, #Why the fuck would you use an int here?...
    entity_status: :byte
  packet :play, 0x1b, :attach_entity,
    entity_id: :int, #...
    vehicle_id: :int,
    leash: :bool
  packet :play, 0x1c, :entity_metadata,
    entity_id: :varint,
    metadata: :metadata
  packet :play, 0x1d, :entity_effect,
    entity_id: :varint,
    effect_id: :byte,
    amplifier: :byte,
    duration: :varint, #seconds
    hide_particles: :bool
  packet :play, 0x1e, :remove_entity_effect,
    entity_id: :varint,
    effect_id: :byte
  packet :play, 0x1f, :set_experience,
    experience_bar: :float, #between 0 and 1
    level: :varint,
    total_experience: :varint
  packet :play, 0x20, :entity_properties,
    entity_id: :varint,
    property_num: :int,
    properties: array(:property_num, [
      key: :string,
      value: :double,
      modifier_num: :varint,
      modifiers: array(:modifier_num, [
        uuid: :uuid,
        amount: :double,
        operation: :byte
      ])
    ])
  packet :play, 0x21, :chunk_data,
    chunk_x: :int,
    chunk_z: :int,
    continuous: :bool,
    section_mask: :u_short,
    chunk_data: :data

  defmodule ChunkData, do: defstruct [:blocks, :light, :skylight]

  defp write_block_types([block | rest], data) do
    write_block_types(rest, <<data::binary, block::little-unsigned-integer-2*8>>)
  end
  defp write_block_types([], data) do
    data
  end

  defp write_block_light([block | rest], data) do
    write_block_light(rest, <<data::bitstring, block::unsigned-integer-4>>)
  end
  defp write_block_light([], data) do
    data
  end

  defp write_biome_data([block | rest], data) do
    write_biome_data(rest, <<data::bitstring, block::unsigned-integer-8>>)
  end
  defp write_biome_data([], data) do
    data
  end

  packet :play, 0x26, :map_chunk_bulk,
    sky_light_sent: :bool,
    chunk_column_count: :varint,
    chunk_metas: array(:chunk_column_count, [
      chunk_x: :int,
      chunk_z: :int,
      section_mask: :u_short]),
    chunk_data: :data
    #chunk_data: array(:chunk_column_count, {fn struct, :chunk_data -> #TODO: Implement decoding as well
    #  blocks = Enum.to_list(Enum.map(1..(16*16*16), fn _ -> 1 end))
    #  data = <<write_block_types(blocks, <<>>)::binary, write_block_light(blocks, <<>>)::binary>>
    #  <<data::binary, data::binary, data::binary, data::binary>>
    #end, nil})
    

  packet :play, 0x39, :player_abilities,
    flags: :byte_flags, #creative, flying, can_fly, godmode
    flying_speed: :float,
    walking_speed: :float

  use McEx.Net.Packets.Macros.End
end
