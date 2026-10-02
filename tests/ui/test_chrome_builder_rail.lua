-- While the contacts pane is the rail, the window's resize minimum drops to
-- rail + divider + minimum chat width, and comes back when it expands.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local L = Theme.LAYOUT
local COLLAPSED_MIN = L.CONTACTS_RAIL_WIDTH + Theme.DIVIDER_THICKNESS + L.CONTENT_MIN_WIDTH

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(1920, 1080)

  local chrome = ChromeBuilder.Build(factory, parent, { width = 400, height = 500, contactsCollapsed = true }, {})
  local frame = chrome.frame

  -- test_collapsed_window_starts_with_the_small_minimum
  local minWidth = frame:GetResizeBounds()
  assert(minWidth == COLLAPSED_MIN, "collapsed build uses the rail minimum, got " .. tostring(minWidth))

  -- test_expanding_restores_the_normal_minimum
  chrome.setContactsCollapsed(false)
  minWidth = frame:GetResizeBounds()
  assert(minWidth == L.WINDOW_MIN_WIDTH, "expanded window uses the normal minimum, got " .. tostring(minWidth))

  -- test_scale_change_keeps_the_collapsed_minimum
  chrome.setContactsCollapsed(true)
  chrome.refreshScale(1)
  minWidth = frame:GetResizeBounds()
  assert(minWidth == COLLAPSED_MIN, "a scale change keeps the rail minimum, got " .. tostring(minWidth))
end
