defmodule McEx.Net.PacketsNew.CompileUtils do
  def test, do: IO.inspect "woo"
end

proto_spec = Poison.Parser.parse!(File.read!("minecraft-data/data/1.8/protocol.json"))
base_module_name = "Elixir.McEx.Net.PacketsNew"

packets_data = 

parse_packet_id = fn("0x" <> hex_id) ->
  {int, ""} = Integer.parse(hex_id, 16)
  int
end

define_packets = fn(mod_name, state_name, mod_data) ->

  for {packet_name, packet_data} <- mod_data do
    packet_name_cap = Mix.Utils.camelize(packet_name)
    struct_name = mod_name <> "." <> packet_name_cap
    struct_def = for e <- packet_data["fields"], do: String.to_atom(e["name"])

    packet_id = parse_packet_id.(packet_data["id"])

    defmodule String.to_atom(struct_name) do
      defstruct(struct_def)
      def id, do: unquote(packet_id)
    end
  end

  defmodule String.to_atom(mod_name) do
    for {packet_name, packet_data} <- mod_data do
      #IO.inspect packet_data
      def test(unquote(packet_name)), do: "woo"
    end
  end

end

for {state_name, state_data} <- proto_spec["states"] do
  state_client = state_data["toServer"]
  state_server = state_data["toClient"]

  state_module_name = Mix.Utils.camelize(state_name)
  client_mod_name = "#{base_module_name}.Client.#{state_module_name}" 
  server_mod_name = "#{base_module_name}.Server.#{state_module_name}"

  define_packets.(client_mod_name, state_name, state_client)
  define_packets.(server_mod_name, state_name, state_server)
end

defmodule McEx.Net.PacketsNew.Runtime do

end
