defmodule GenRoom do

  @callback handle_join(pid, params, state) :: {:allow, state} | {:decline, state} when state: term, params: term
  @callback handle_leave(pid, state) :: {:ok, state} when state: term

  defmacro __using__() do
    quote location: :keep do
      @behaviour GenRoom

      defoverridable [handle_join: 3, room_leave: 2]
    end
  end

  use GenServer

end
