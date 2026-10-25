local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local PanelHost = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PanelHost")
local PanelBadge = require("WhisperMessenger.UI.Shared.PanelBadge")

-- The tab reads badge() the same way the icon number does.
local function tabBadgeFor(value)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Window", nil)
  local last = nil
  local host = PanelHost.Create({
    factory = factory,
    parent = parent,
    theme = Theme,
    addTab = function()
      return {
        setBadge = function(n)
          last = n
        end,
      }
    end,
    onTabClick = function() end,
  })
  host.register("ca", {
    title = "Alerts",
    onShow = function() end,
    badge = function()
      return value
    end,
  })
  return last
end

return function()
  -- test_tab_rounds_a_fractional_badge_down
  do
    local count = tabBadgeFor(2.5)
    assert(count == 2, "2.5 shows 2, got " .. tostring(count))
  end

  -- test_tab_hides_a_badge_below_one
  do
    local count = tabBadgeFor(0.5)
    assert(count == 0, "0.5 shows nothing, got " .. tostring(count))
  end

  -- test_tab_hides_a_nan_badge
  do
    local count = tabBadgeFor(0 / 0)
    assert(count == 0, "NaN shows nothing, got " .. tostring(count))
  end

  -- test_tab_clamps_an_infinite_badge
  do
    local count = tabBadgeFor(math.huge)
    assert(count == PanelBadge.MAX_COUNT, "infinity is clamped, got " .. tostring(count))
  end
end
