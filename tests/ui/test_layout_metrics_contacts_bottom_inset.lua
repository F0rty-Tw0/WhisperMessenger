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

  -- test_contacts_list_height_subtracts_bottom_inset
  do
    local sizing = LayoutMetrics.CalculateRelayout({ contactsBottomInset = 24 }, 920, 580, nil, Theme)
    local expected = sizing.contactsHeight - sizing.searchTotalHeight - 24
    assert(sizing.contactsListHeight == expected, "expected list height " .. expected .. ", got " .. tostring(sizing.contactsListHeight))
    assert(sizing.contactsBottomInset == 24, "expected bottom inset passthrough, got " .. tostring(sizing.contactsBottomInset))
  end
end
