local PanelBadge = require("WhisperMessenger.UI.Shared.PanelBadge")

local function returning(value)
  return function()
    return value
  end
end

return function()
  -- test_whole_counts_pass_through
  do
    local count = PanelBadge.Read(returning(3))
    assert(count == 3, "got " .. tostring(count))
  end

  -- test_fractions_round_down
  do
    local count = PanelBadge.Read(returning(2.5))
    assert(count == 2, "got " .. tostring(count))
  end

  -- test_counts_below_one_are_nothing
  do
    local count = PanelBadge.Read(returning(0.5))
    assert(count == 0, "got " .. tostring(count))
  end

  -- test_nan_is_nothing
  do
    local count = PanelBadge.Read(returning(0 / 0))
    assert(count == 0, "got " .. tostring(count))
  end

  -- test_infinity_is_clamped_to_the_maximum
  do
    local count = PanelBadge.Read(returning(math.huge))
    assert(count == PanelBadge.MAX_COUNT, "got " .. tostring(count))
  end

  -- test_negative_infinity_is_nothing
  do
    local count = PanelBadge.Read(returning(-math.huge))
    assert(count == 0, "got " .. tostring(count))
  end

  -- test_non_numbers_are_nothing
  do
    local count = PanelBadge.Read(returning("3"))
    assert(count == 0, "a numeric string is not a count, got " .. tostring(count))
  end

  -- test_an_erroring_badge_is_nothing
  do
    local count = PanelBadge.Read(function()
      error("boom")
    end)
    assert(count == 0, "got " .. tostring(count))
  end

  -- test_a_missing_badge_is_nothing
  do
    assert(PanelBadge.Read(nil) == 0)
  end

  -- test_a_secret_count_is_nothing
  do
    local saved = _G.issecretvalue
    _G.issecretvalue = function(value)
      return value == 7
    end
    local ok, count = pcall(PanelBadge.Read, returning(7))
    _G.issecretvalue = saved
    assert(ok, count)
    assert(count == 0, "a secret count is not read, got " .. tostring(count))
  end

  -- test_a_badge_that_reads_itself_again_is_nothing_the_second_time
  do
    local depth = 0
    local badge
    badge = function()
      depth = depth + 1
      local inner = PanelBadge.Read(badge)
      assert(inner == 0, "the nested read is nothing, got " .. tostring(inner))
      return 4
    end
    assert(PanelBadge.Read(badge) == 4, "the outer read still counts")
    assert(depth == 1, "the callback ran once, got " .. depth)
    assert(PanelBadge.Read(function()
      return 2
    end) == 2)
    depth = 0
    assert(PanelBadge.Read(badge) == 4 and depth == 1, "the guard clears after a read")
  end

  -- test_badges_that_read_each_other_do_not_nest
  do
    local calls = 0
    local first, second
    first = function()
      calls = calls + 1
      PanelBadge.Read(second)
      return 1
    end
    second = function()
      calls = calls + 1
      PanelBadge.Read(first)
      return 1
    end
    assert(PanelBadge.Read(first) == 1, "the outer read still counts")
    assert(calls == 1, "a read inside another panel's badge is nothing, got " .. calls .. " calls")
  end
end
