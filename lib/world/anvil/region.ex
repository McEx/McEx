defmodule McEx.World.AnvilRegion do
  # Client
  def test do
    {:ok, pid} = start_link("./testdata/", {0, 0})
    GenServer.call(pid, {:read_chunk, {0, 0}})
    pid
  end
  def start_link(file_path, pos) do
    GenServer.start_link(__MODULE__, {file_path, pos})
  end

  # Server
  use GenServer
  use Bitwise

  defmodule State do
    defstruct device: nil, chunk_map: nil, file_name: nil, pos: nil
  end

  def init({path, pos}) do
    file_name = format_region_file_name(path, pos)
    {:ok, device} = File.open(file_name, [:read, :write])
    {:ok, locations} = :file.pread(device, 0, 4096)

    chunk_map = chunk_map_from_header(locations, :array.new(1024, default: nil, fixed: true))

    {:ok, %State{
      device: device,
      file_name: file_name,
      pos: pos,
      chunk_map: chunk_map,
    }}
  end

  def handle_call({:read_chunk, pos={x, z}}, _from, state) do
    IO.inspect read_chunk(state, pos)
    {:reply, 0, state}
  end

  def read_chunk(state, pos={x, z}) do
    index = chunk_coords_to_index(pos)
    {_, _, offset, count} = :array.get(index, state.chunk_map)
    <<length::big-unsigned-integer-4*8, rest::binary>> = read_sectors(state.device, offset, count)
    data = read_chunk_data(binary_part(rest, 0, length))
    decode_chunk_data(data)
  end
  def read_chunk_data(<<2::unsigned-integer-1*8, data::binary>>) do
    z = :zlib.open
    :zlib.inflateInit(z)
    data_dec = :zlib.inflate(z, data)
    :zlib.inflateEnd(z)
    :zlib.close(z)
    IO.iodata_to_binary(data_dec)
  end
  def decode_chunk_data(data) do
    nbt = McEx.NBT.Read.read(data)
  end

  def read_sectors(device, offset, count) do
    {:ok, data} = :file.pread(device, offset*4096, count*4096)
    data
  end

  def format_region_file_name(path, {x, z}) when is_integer(x) and is_integer(z), do: "#{path}r.#{x}.#{z}.mca"
  def chunk_coords_to_index({x, z}) when 0<=x and x<32 and 0<=z and x<32, do: (x &&& 31) + ((z &&& 31) * 32)

  def chunk_map_from_header(header, array), do: chunk_map_from_header(header, 0, array)
  def chunk_map_from_header(<<>>, _num, acc), do: acc
  def chunk_map_from_header(<<offset::big-unsigned-integer-3*8, sector_count::unsigned-integer-1*8, rest::binary>>, num, arr) do
    pos = {num >>> 5, rem(num, 32)}
    arr = if offset == sector_count == 0 do
      arr
    else
      :array.set(num, {num, pos, offset, sector_count}, arr)
    end
    chunk_map_from_header(rest, num+1, arr)
  end

end
