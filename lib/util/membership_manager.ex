defmodule McEx.Util.MembershipManager do

  defstruct groups_members: %{}, monitors: %{}

  def init(groups) do
    %__MODULE__{
      groups_members: groups
      |> Enum.map(fn ident -> {ident, %{}} end) |> Enum.into(%{}),
    }
  end

  def join(%__MODULE__{} = state, group, pid, member_state \\ nil) do
    case Map.fetch(state.groups_members[group], pid) do
      {:ok, _} -> :already_member
      :error ->
        mon_ref = Process.monitor(pid)
        state = %{state |
                  monitors: Map.put(state.monitors, mon_ref, {group, pid}),
                  groups_members: put_in(state.groups_members, [group, pid],
                                         {mon_ref, member_state})
                 }
        {:ok, state}
    end
  end
  def join!(state, group, pid, member_state \\ nil) do
    {:ok, state} = join(state, group, pid, member_state)
    state
  end

  def leave(%__MODULE__{} = state, group, pid) do
    case Map.pop(state.groups_members[group], pid) do
      {{mon_ref, member_state}, group_members} ->
        {_, monitors} = Map.pop(state.monitors, mon_ref)
        Process.demonitor(mon_ref)
        state = %{state |
                  groups_members: Map.put(state.groups_members, group, group_members),
                  monitors: monitors,
                 }
        {:ok, state, member_state}
      {nil, _state} -> :not_member
    end
  end

  def mon_ref_leave(%__MODULE__{} = state, mon_ref) do
    case Map.fetch(state.monitors, mon_ref) do
      {:ok, {group, pid}} ->
        case leave(state, group, pid) do
          :not_member -> :not_member
          {:ok, state, member_state} ->
            {:ok, state, group, member_state}
        end
      :error -> :not_member
    end
  end

  def member?(%__MODULE__{} = state, group, pid) do
    member_state(state, group, pid) != :not_member
  end

  def member_state(%__MODULE__{} = state, group, pid) do
    case state.groups_members[group][pid] do
      nil -> :not_member
      {_, member_state} -> {:ok, member_state}
    end
  end
  def update_member_state(%__MODULE__{} = state, group, pid, fun) do
    update_in(state, [:groups_members, group, pid], fn {mon_ref, member_state} ->
      {mon_ref, fun.(member_state)}
    end)
  end
  def put_member_state(%__MODULE__{} = state, group, pid, member_state) do
    update_member_state(state, group, pid, fn _ -> member_state end)
  end

end
