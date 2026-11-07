local FakeUI = require("tests.helpers.fake_ui")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local L = Theme.LAYOUT

-- x of a button's right edge inside the title bar, following its LEFT->RIGHT chain.
local function rightEdge(button, titleBar)
  local point, relativeTo, relativePoint, x = button:GetPoint()
  assert(point == "LEFT", "left cluster is anchored by LEFT")
  if relativeTo == titleBar then
    assert(relativePoint == "LEFT", "first button hangs off the bar's left edge")
    return x + button.width
  end
  assert(relativePoint == "RIGHT", "next button follows the previous one")
  return rightEdge(relativeTo, titleBar) + x + button.width
end

return function()
  -- test_compact_docked_title_clears_the_left_buttons
  Hud.Configure("off")
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local width = L.COMPACT_WINDOW_WIDTH
  local chrome = ChromeBuilder.Build(factory, parent, { width = width, height = 640 }, { useNativeChrome = false, compactLayout = true })
  chrome.setMarkAllReadShown(true)

  local barWidth = width - 2 -- ModernChrome: TOPLEFT +1, TOPRIGHT -1
  local point, relativeTo, relativePoint, x = chrome.title:GetPoint()
  assert(point == "CENTER" and relativeTo == chrome.titleBar and relativePoint == "CENTER", "title centred on the bar")
  local titleLeft = barWidth / 2 + x - chrome.title:GetStringWidth() / 2
  local clusterRight = rightEdge(chrome.markAllReadButton, chrome.titleBar)
  assert(titleLeft >= clusterRight + L.TITLE_BUTTON_GAP, "title starts at " .. titleLeft .. ", mark-all-read ends at " .. clusterRight)
  print("PASS: test_title_bar_compact_clearance")
end
