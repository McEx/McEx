defmodule McEx.MembershipManagerTest do
  use ExUnit.Case, async: true

  alias McEx.Util.MembershipManager

  test "init working" do
    MembershipManager.init([])
    MembershipManager.init([:single_arg])
    MembershipManager.init([:multiple, :several, :args])
  end

  test "process membership lifecycle" do
    manager = MembershipManager.init([:one, :two])

    test_proc_1 = spawn_test_proc
    test_proc_2 = spawn_test_proc

    manager = manager
    |> MembershipManager.join!(:one, test_proc_1, :p1s1)
    |> MembershipManager.join!(:one, test_proc_2, :p2s1)
    |> MembershipManager.join!(:two, test_proc_1, :p1s2)

    assert MembershipManager.member?(manager, :one, test_proc_1)
    assert MembershipManager.member?(manager, :one, test_proc_2)
    assert MembershipManager.member?(manager, :two, test_proc_1)
    refute MembershipManager.member?(manager, :two, test_proc_2)

    {:ok, manager, :p1s1} = MembershipManager.leave(manager, :one, test_proc_1)
    refute MembershipManager.member?(manager, :one, test_proc_1)
    assert MembershipManager.member?(manager, :one, test_proc_2)

    {:ok, :p2s1} = MembershipManager.member_state(manager, :one, test_proc_2)

    Process.exit(test_proc_2, :kill)
    assert_receive {:DOWN, mon_ref, :process, _, _}
    {:ok, manager, :one, _} = MembershipManager.mon_ref_leave(manager, mon_ref)

    refute MembershipManager.member?(manager, :one, test_proc_2)
    refute MembershipManager.member?(manager, :two, test_proc_2)
  end

  def spawn_test_proc do
    spawn(&test_proc_loop/0)
  end
  def test_proc_loop do
    receive do
      :loop -> test_proc_loop
    end
  end

end
