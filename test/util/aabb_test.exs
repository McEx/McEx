defmodule McEx.Util.AABBTest do
  use ExUnit.Case, async: true
  alias McEx.Util.AABB

  test "aabb from points" do
    aabb = %AABB{x: {0, 1}, y: {0, 1}, z: {0, 1}}
    assert AABB.from_points({0, 1, 0}, {1, 0, 1}) == aabb
  end

  test "aabb axis clamp collide" do
    aabb1 = AABB.from_points({1, 1, 1}, {2, 2, 2})
    aabb2 = AABB.from_points({1, 3, 1}, {2, 4, 2})
    assert AABB.clamp_collide_axis(:y, aabb1, aabb2, -5) == -1
    assert AABB.clamp_collide_axis(:z, aabb1, aabb2, -5) == -5
    assert AABB.clamp_collide_axis(:y, aabb2, aabb1, 5) == 1
  end

  test "range comparators" do
    a = {0, 2}
    b = {3, 5}
    c = {2, 4}
    d = {-2, 0}
    e = {-3, -1}

    # a, b
    assert AABB.range_gt?(a, b)
    assert AABB.range_gte?(a, b)
    refute AABB.range_lt?(a, b)
    refute AABB.range_lte?(a, b)

    # a, c
    refute AABB.range_gt?(a, c)
    assert AABB.range_gte?(a, c)
    refute AABB.range_lt?(a, c)
    refute AABB.range_lte?(a, c)

    # a, d
    refute AABB.range_gt?(a, d)
    refute AABB.range_gte?(a, d)
    refute AABB.range_lt?(a, d)
    assert AABB.range_lte?(a, d)

    # a, e
    refute AABB.range_gt?(a, e)
    refute AABB.range_gte?(a, e)
    assert AABB.range_lt?(a, e)
    assert AABB.range_lte?(a, e)
  end

  test "range tuple intersect" do
    assert AABB.range_intersect?({0, 2}, {1, 2})
    refute AABB.range_intersect?({0, 2}, {2, 4})
    refute AABB.range_intersect?({2, 4}, {0, 2})
    assert AABB.range_intersect?({0, 4}, {1, 2})
    assert AABB.range_intersect?({1, 2}, {0, 4})
    assert AABB.range_intersect?({0, 2}, {1, 1})
    assert AABB.range_intersect?({1, 1}, {0, 2})
  end

  test "range tuple sorting" do
    assert AABB.sort_range_tuple(1, 0) == {0, 1}
    assert AABB.sort_range_tuple(0, 1) == {0, 1}
    assert AABB.sort_range_tuple(5, -5) == {-5, 5}
    assert AABB.sort_range_tuple(5, 5) == {5, 5}
  end
end
