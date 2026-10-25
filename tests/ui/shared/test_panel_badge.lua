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
end
