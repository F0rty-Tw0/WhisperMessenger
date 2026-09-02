local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local FakeUI = require("tests.helpers.fake_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

local function bottomAnchorY(scrollFrame)
  for i = #(scrollFrame.points or {}), 1, -1 do
    local pt = scrollFrame.points[i]
    if pt[1] == "BOTTOMRIGHT" then
      return pt[5]
    end
  end
  return nil
end

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)

  local settingsConfig = { showGroupChats = true }
  local window = MessengerWindow.Create(factory, {
    contacts = {},
    settingsConfig = settingsConfig,
  })

  local scrollFrame = window.contacts.scrollFrame
  local width = window.frame:GetWidth()
  local height = window.frame:GetHeight()
  local tabHeight = TabToggle.HEIGHT

  -- test_contacts_list_stops_above_tab_toggle_when_shown
  do
    local sizing = LayoutMetrics.CalculateRelayout({ contactsBottomInset = tabHeight }, width, height, nil, Theme)
    assert(
      bottomAnchorY(scrollFrame) == tabHeight,
      "expected list bottom anchored " .. tabHeight .. "px above pane, got " .. tostring(bottomAnchorY(scrollFrame))
    )
    assert(
      scrollFrame:GetHeight() == sizing.contactsListHeight,
      "expected list height " .. sizing.contactsListHeight .. ", got " .. tostring(scrollFrame:GetHeight())
    )
  end

  -- test_contacts_list_reclaims_space_when_tab_toggle_hidden
  do
    settingsConfig.showGroupChats = false
    window.refreshTabToggleVisibility()
    local sizing = LayoutMetrics.CalculateRelayout({}, width, height, nil, Theme)
    assert(bottomAnchorY(scrollFrame) == 0, "expected list bottom flush with pane when tabs hidden, got " .. tostring(bottomAnchorY(scrollFrame)))
    assert(
      scrollFrame:GetHeight() == sizing.contactsListHeight,
      "expected full list height " .. sizing.contactsListHeight .. ", got " .. tostring(scrollFrame:GetHeight())
    )
  end

  -- test_contacts_list_shrinks_again_when_tab_toggle_reshown
  do
    settingsConfig.showGroupChats = true
    window.refreshTabToggleVisibility()
    assert(bottomAnchorY(scrollFrame) == tabHeight, "expected list bottom re-raised above tabs, got " .. tostring(bottomAnchorY(scrollFrame)))
  end

  _G.UIParent = savedUIParent
end
