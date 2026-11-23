local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

-- The bottom of a settings page: its Reset to Defaults button, the marker
-- the options scroll view sizes to, and the width the page lays out at.
local PageFooter = {}

-- Narrowest width a settings page lays out at.
local MIN_SETTINGS_WIDTH = 160

-- Ghost option button bound to `panel`, so a theme change restyles it.
-- The page anchors it and relabels it on a language change.
function PageFooter.CreateResetButton(factory, frame, panel, label, onClick)
  local button = panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      label,
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, ghost = true }
    ),
    { type = "optionButton" }
  )
  button:SetScript("OnClick", onClick)
  return button
end

-- Padding spacer under `anchor`, the page's last control. The options
-- scroll view reads frame._wmBottomMarker to size the scroll content to
-- the page's extent.
function PageFooter.AddBottomMarker(factory, frame, anchor)
  local spacer = factory.CreateFrame("Frame", nil, frame)
  spacer:SetSize(1, Theme.CONTENT_PADDING)
  spacer:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
  frame._wmBottomMarker = spacer
  return spacer
end

-- Width a control page lays out at, or nil when `width` is not a positive
-- number (nothing to lay out yet).
function PageFooter.ClampPanelWidth(width)
  if type(width) ~= "number" or width <= 0 then
    return nil
  end
  return math.min(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, math.max(MIN_SETTINGS_WIDTH, math.floor(width)))
end

ns.SettingsControlsPageFooter = PageFooter
return PageFooter
