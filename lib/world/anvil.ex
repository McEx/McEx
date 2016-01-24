defmodule McEx.World.Anvil do
  
  def read_file(path) do
    {:ok, data} = File.read(path)
    read(data)
  end
  def read(bin) do
    McEx.NBT.Read.read(bin)
  end

end

defmodule McEx.World.AnvilRegion do
  # Client


  # Server
  use GenServer

  def init({file_path}) do
    {:ok, device} = File.open(file_path, [:read, :write])
    {:ok, device}
  end

end
