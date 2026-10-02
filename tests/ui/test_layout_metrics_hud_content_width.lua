local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local RetailHud = require("tests.helpers.retail_hud")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")

-- Under a Native WoW HUD the conversation pane is anchored inside the
-- template border, so it is narrower than the window by the HUD's side
-- insets. The transcript, header and composer are laid out at
-- `contentWidth`, so it must match that pane, or sent messages spill past
-- its right edge onto the window border.

local WIDTH, HEIGHT = 920, 580

local function paneWidth(sizing)
  local insets = Hud.ContentInsets(Theme.LAYOUT)
  return WIDTH - insets.left - insets.right - sizing.contactsWidth - Theme.DIVIDER_THICKNESS
end

return function()
  -- test_classic_hud_content_width_matches_the_pane
  Hud.Configure("classic")
  local classic = LayoutMetrics.CalculateRelayout({ nativeChrome = true }, WIDTH, HEIGHT, nil, Theme)
  local classicPane = paneWidth(classic)
  Hud.Configure("off")
  assert(classic.contentWidth == classicPane, "classic: content width " .. classic.contentWidth .. " vs pane " .. classicPane)

  -- test_retail_hud_content_width_matches_the_pane
  RetailHud.With(function()
    local retail = LayoutMetrics.CalculateRelayout({ nativeChrome = true }, WIDTH, HEIGHT, nil, Theme)
    local retailPane = paneWidth(retail)
    assert(retail.contentWidth == retailPane, "retail: content width " .. retail.contentWidth .. " vs pane " .. retailPane)
  end)

  -- test_modern_content_width_is_unchanged
  do
    local modern = LayoutMetrics.CalculateRelayout({}, WIDTH, HEIGHT, nil, Theme)
    local expected = WIDTH - modern.contactsWidth - Theme.DIVIDER_THICKNESS
    assert(modern.contentWidth == expected, "modern: content width " .. modern.contentWidth .. " vs " .. expected)
  end
end
