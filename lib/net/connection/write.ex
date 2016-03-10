defmodule McEx.Net.ConnectionNew.Write do
  use GenServer
  alias McEx.Net.Packets.Server
  require Logger

  defmodule State do
    defstruct socket: nil, write_state: nil
  end

  def start_link(socket) do
    GenServer.start_link(__MODULE__, {socket})
  end

  def init({socket}) do
    state = %State{
      socket: socket,
      write_state: McProtocol.Transport.Write.initial_state,
    }
    {:ok, state}
  end

  # Blocking, for things like the kick packet when we want to close the TCP
  # socket right after the packet is sent.
  def handle_call({:write_struct, struct}, state) do
    state = write_struct(struct, state)
    {:reply, :ok, state}
  end

  # Nonblocking, for normal packets
  # TODO: Change to cast
  def handle_info({:write_struct, struct}, state) do
    state = write_struct(struct, state)
    {:noreply, state}
  end

  # TODO: Change to call
  def handle_info({:set_encr, encr_data}, state) do
    {:noreply, 
      %{state | 
        write_state: McProtocol.Transport.Write.set_encryption(
          state.write_state, encr_data),
      }
    }
  end
  # TODO: Change to call
  def handle_info({:set_compression, compr_threshold}, state) do
    {:noreply, 
      %{state | 
        write_state: McProtocol.Transport.Write.set_compression(
          state.write_state, compr_threshold),
      }
    }
  end

  def write_struct(struct, state) do
    packet_data = try do
      Server.write_packet(struct)
    rescue
      error -> handle_write_error(error, struct, state)
    end

    write_state = state.write_state
    {out_data, write_state} = McProtocol.Transport.Write.process(packet_data, write_state)
    state = %{ state | write_state: write_state }

    do_socket_write(out_data, state)
  
    # TODO: This should only be done when big packets are sent
    :erlang.garbage_collect

    state
  end

  defp do_socket_write(data, %State{socket: socket}) do
    case :gen_tcp.send(socket, data) do
      :ok -> nil
      _ -> raise ClosedError
    end
  end

  def deflate(data) do
    # TODO: Reuse zstream
    z = :zlib.open
    :zlib.deflateInit(z)
    compr = :zlib.deflate(z, data, :finish)
    :zlib.deflateEnd(z)
    :zlib.close(z)
    compr
  end

  def handle_write_error(error, struct, state) do
    error_format = Exception.format(:error, error)
    error_msg = error_format <> "When encoding packet:\n" <> inspect(struct) <> "\n"
    Logger.error(error_msg)
    exit(:shutdown)
  end
end
