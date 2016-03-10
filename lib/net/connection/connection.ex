defmodule McEx.Net.ConnectionNew do
  use GenServer

  defmodule State do
    defstruct socket: nil, read: nil, write: nil, controlling: nil,
    read_state: nil, protocol_handler: nil, handler_state: nil

    def handler_state(state), do: state.handler_state
    def handler_state(state, handler_state), do: %{ state | handler_state: handler_state }

    def write_packet(state, packet) do
      send state.write, {:write_struct, packet}
    end

    def set_encr(state, encr = %McProtocol.Crypto.Transport.CryptData{}) do
      send state.write, {:set_encr, encr}
      %{ state |
        read_state: McProtocol.Transport.Read.set_encryption(state.read_state, encr)
      }
    end
    def set_compression(state, compr) do
      send state.write, {:set_compression, compr}
      %{ state |
        read_state: McProtocol.Transport.Read.set_compression(state.read_state, compr)
      }
    end
  end

  def start_link(socket) do
    GenServer.start_link(__MODULE__, {socket})
  end

  def init({socket}) do
    #{:ok, write_pid} = Task.start_link(McEx.Net.Connection.Write, :start_write, [socket])
    {:ok, write_pid} = McEx.Net.ConnectionNew.Write.start_link(socket)
    #{:ok, read_pid} = Task.start_link(McEx.Net.Connection.Read, :start_read, [socket, write_pid, self])

    state = %State{
      socket: socket,
      read: self,
      read_state: McProtocol.Transport.Read.initial_state,
      write: write_pid,
      controlling: self,
      protocol_handler: McEx.Net.LegacyProtocolHandler,
      handler_state: McEx.Net.LegacyProtocolHandler.initial_state,
    }
    |> recv_once

    {:ok, state}
  end

  def handle_cast({:die_with, pid}, state) do
    Process.link(pid)
    {:noreply, state}
  end
  def handle_info({:die_with, pid}, state) do
    Process.link(pid)
    {:noreply, state}
  end

  def handle_info({:tcp, socket, data}, state = %State{socket: socket}) do
    {packets, read_state} = McProtocol.Transport.Read.process(data, state.read_state)
    state = %{ state |
      read_state: read_state,
    }

    state = Enum.reduce(packets, state, fn packet, in_state ->
      apply(state.protocol_handler, :packet_in, [packet, in_state])
    end)

    state = state |> recv_once
    {:noreply, state}
  end
  def handle_info({:tcp_closed, socket}, state = %State{socket: socket}) do
    {:stop, :tcp_closed, state}
  end

  def recv_once(state) do
    :inet.setopts(state.socket, active: :once)
    state
  end
end
