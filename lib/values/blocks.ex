defmodule McEx.Values.Blocks do
  blocks = Poison.Parser.parse!(File.read!("minecraft-data/data/1.8/blocks.json"))

  for block <- blocks do
    atom = String.to_atom(block["name"])
    def id_to_atom(unquote(block["id"])), do: unquote(atom)

    id = block["id"]
    def name(unquote(id)), do: unquote(block["displayName"])
    def hardness(unquote(id)), do: unquote(block["hardness"])
    def stack_size(unquote(id)), do: unquote(block["stackSize"])
    def diggable(unquote(id)), do: unquote(block["diggable"])

    if block["boundingBox"] != nil do
      def bounding_box(unquote(id)), do: unquote(String.to_atom(block["boundingBox"]))
    end
    if block["material"] != nil do
      def material(unquote(id)), do: unquote(String.to_atom(block["material"]))
    end

    for {id_str, true} <- block["harvestTools"] || [] do
      {id_harvestable, ""} = Integer.parse(id_str)
      def harvestable_with(unquote(id), unquote(id_harvestable)), do: true
    end
  end

  def harvestable_with(_, _), do: false
end
