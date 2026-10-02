local Theme = require("WhisperMessenger.UI.Theme")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")

return function()
  -- test_contacts_list_height_ignores_missing_inset
  do
    local sizing = LayoutMetrics.CalculateRelayout({}, 920, 580, nil, Theme)
    local expected = sizing.contactsHeight - sizing.searchTotalHeight
    assert(sizing.contactsListHeight == expected, "expected list height " .. expected .. ", got " .. tostring(sizing.contactsListHeight))
    assert(sizing.contactsBottomInset == 0, "expected zero bottom inset by default, got " .. tostring(sizing.contactsBottomInset))
  end

  -- test_hud_list_clears_the_panel_border
  do
    local sizing = LayoutMetrics.CalculateRelayout({ nativeChrome = true }, 920, 580, nil, Theme)
    assert(sizing.contactsBottomInset == Theme.LAYOUT.HUD_PANEL_PADDING, "HUD list stops above the panel border")
  end
end
