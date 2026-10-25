local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local UnreadSummary = require("WhisperMessenger.UI.Shared.UnreadSummary")

local function withBadge(value)
  return {
    badge = function()
      return value
    end,
  }
end

return function()
  -- test_badge_sum_adds_positive_counts
  do
    local registry = PanelRegistry.New()
    registry.register("two", withBadge(2))
    registry.register("zero", withBadge(0))
    registry.register("negative", withBadge(-1))
    registry.register("string", withBadge("3"))
    registry.register("nil", withBadge(nil))
    registry.register("error", {
      badge = function()
        error("boom")
      end,
    })
    registry.register("no badge", {})
    local sum = registry.badgeSum()
    assert(sum == 2, "only positive numbers count, got " .. tostring(sum))
  end

  -- test_badge_sum_floors_fractions
  do
    local registry = PanelRegistry.New()
    registry.register("a", withBadge(1.9))
    registry.register("b", withBadge(0.5))
    local sum = registry.badgeSum()
    assert(sum == 1, "fractions floor, got " .. tostring(sum))
  end

  -- test_badge_sum_counts_a_fractional_badge_like_its_tab
  do
    local registry = PanelRegistry.New()
    registry.register("a", withBadge(2.5))
    assert(registry.badgeSum() == 2, "2.5 adds 2, got " .. tostring(registry.badgeSum()))
  end

  -- test_badge_sum_ignores_nan
  do
    local registry = PanelRegistry.New()
    registry.register("a", withBadge(0 / 0))
    registry.register("b", withBadge(1))
    assert(registry.badgeSum() == 1, "NaN adds nothing, got " .. tostring(registry.badgeSum()))
  end

  -- test_badge_sum_clamps_an_infinite_badge_into_sane_text
  do
    local registry = PanelRegistry.New()
    registry.register("a", withBadge(math.huge))
    local text = UnreadSummary.Format(0, registry.badgeSum())
    assert(text == "999 in addon pages", "got " .. tostring(text))
  end

  -- test_first_badged_key_skips_a_badge_below_one
  do
    local registry = PanelRegistry.New()
    registry.register("half", withBadge(0.5))
    assert(registry.firstBadgedKey() == nil, "0.5 is no badge, got " .. tostring(registry.firstBadgedKey()))
  end

  -- test_first_badged_key_skips_nan
  do
    local registry = PanelRegistry.New()
    registry.register("nan", withBadge(0 / 0))
    assert(registry.firstBadgedKey() == nil, "NaN is no badge, got " .. tostring(registry.firstBadgedKey()))
  end

  -- test_badge_sum_reads_the_badge_on_every_call
  do
    local registry = PanelRegistry.New()
    local count = 0
    registry.register("ca", {
      badge = function()
        return count
      end,
    })
    assert(registry.badgeSum() == 0)
    count = 4
    assert(registry.badgeSum() == 4, "a later call sees the new count")
  end

  -- test_badge_sum_of_no_panels_is_zero
  assert(PanelRegistry.New().badgeSum() == 0)

  -- test_first_badged_key_follows_registration_order_and_skips_bad_badges
  do
    local registry = PanelRegistry.New()
    assert(registry.firstBadgedKey() == nil, "no panels, no key")
    registry.register("zero", withBadge(0))
    registry.register("error", {
      badge = function()
        error("boom")
      end,
    })
    registry.register("no badge", {})
    assert(registry.firstBadgedKey() == nil, "no positive badge, no key")
    registry.register("first", withBadge(0.5 + 1))
    registry.register("second", withBadge(9))
    assert(registry.firstBadgedKey() == "first", "first positive badge wins, got " .. tostring(registry.firstBadgedKey()))
  end
end
