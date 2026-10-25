local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local FakeUI = require("tests.helpers.fake_ui")

-- The Whispers/Groups tabs hang below the window, so the contact list keeps
-- its full height whether they show or not.

local function bottomAnchorY(scrollFrame)
  for i = #(scrollFrame.points or {}), 1, -1 do
    local pt = scrollFrame.points[i]
    if pt[1] == "BOTTOMLEFT" then
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
  local fullHeight = LayoutMetrics.CalculateRelayout({}, width, height, nil, Theme).contactsListHeight

  -- test_contacts_list_keeps_full_height_with_tabs_shown
  assert(window.tabToggle.frame:IsShown() == true, "setup: tabs show with groups on")
  assert(bottomAnchorY(scrollFrame) == 0, "list bottom flush with the pane, got " .. tostring(bottomAnchorY(scrollFrame)))
  assert(scrollFrame:GetHeight() == fullHeight, "list keeps its full height, got " .. tostring(scrollFrame:GetHeight()))

  -- test_contacts_list_unchanged_when_tabs_hide_and_reshow
  settingsConfig.showGroupChats = false
  window.refreshTabToggleVisibility()
  assert(window.tabToggle.frame:IsShown() == false, "tabs hide with a single mode")
  assert(scrollFrame:GetHeight() == fullHeight, "list height unchanged with tabs hidden")
  settingsConfig.showGroupChats = true
  window.refreshTabToggleVisibility()
  assert(bottomAnchorY(scrollFrame) == 0 and scrollFrame:GetHeight() == fullHeight, "list height unchanged with tabs reshown")

  -- test_relayout_relifts_the_strip
  -- The strip is the window's child; the window is re-leveled when raised.
  window.contactsPane:SetFrameLevel(40)
  window.frame:GetScript("OnSizeChanged")(window.frame, 900, 560)
  assert(window.tabToggle.frame:GetFrameLevel() == 41, "strip one level above the pane, got " .. tostring(window.tabToggle.frame:GetFrameLevel()))

  -- test_options_page_hides_the_strip
  window.optionsButton.scripts.OnClick(window.optionsButton)
  assert(window.tabToggle.frame:IsShown() == false, "options page hides the strip")
  window.backButton.scripts.OnClick(window.backButton)
  assert(window.tabToggle.frame:IsShown() == true, "closing options shows the strip again")

  _G.UIParent = savedUIParent
end
