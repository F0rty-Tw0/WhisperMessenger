local Metrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")

local L = Theme.LAYOUT
local EDGES = L.CONTACTS_PANE_LEFT_INSET + L.CONTENT_PANE_RIGHT_INSET

return function()
  -- test_both_panes_fill_the_compact_window
  do
    local result = Metrics.CalculateRelayout({ compactLayout = true }, 360, 640, 180, Theme)
    assert(result.contactsWidth == 360 - EDGES, "list fills the window, got " .. tostring(result.contactsWidth))
    assert(result.contentWidth == 360 - EDGES, "chat fills the window, got " .. tostring(result.contentWidth))
  end

  -- test_compact_panes_clear_the_native_hud_border
  do
    Hud.Configure("classic")
    local insets = Hud.ContentInsets(L)
    local result = Metrics.CalculateRelayout({ compactLayout = true, nativeChrome = true }, 360, 640, 180, Theme)
    Hud.Configure("off")
    local expected = 360 - insets.left - insets.right - EDGES
    assert(result.contentWidth == expected, "HUD chat width, got " .. tostring(result.contentWidth))
    assert(result.contactsWidth == expected, "HUD list width, got " .. tostring(result.contactsWidth))
  end

  -- test_wide_compact_window_lays_settings_out_like_the_classic_window
  do
    local wide = Metrics.CalculateRelayout({ compactLayout = true, compactWide = true }, 900, 640, 180, Theme)
    local classic = Metrics.CalculateRelayout({}, 900, 640, 180, Theme)
    assert(wide.optionsContentWidth == classic.optionsContentWidth, "settings keep their classic width")
    assert(wide.optionsMenuWidth == classic.optionsMenuWidth, "settings nav keeps its classic width")
  end
end
