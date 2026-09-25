local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- The settings pages' line look: a one-pixel hairline, snapped to the pixel
-- grid, in the section-header colour, fading out toward its outer end.
-- Header draws its title lines with it; Create builds a free-standing
-- divider from two halves that meet, full strength, in the middle.
local Divider = {}

function Divider.createLine(frame)
  local line = frame:CreateTexture(nil, "ARTWORK")
  line:SetHeight(UIHelpers.hairlineThickness(frame, 1))
  UIHelpers.snapToPixelGrid(line)
  return line
end

-- leftLine fades out to the left, rightLine fades out to the right.
function Divider.paint(leftLine, rightLine, activeTheme)
  local color = activeTheme.COLORS.contacts_border_right or activeTheme.COLORS.divider
  UIHelpers.applyHorizontalFadeLeft(leftLine, color)
  UIHelpers.applyHorizontalFade(rightLine, color)
end

-- Anchor the divider by its left half; the right half follows it.
function Divider.Create(frame)
  local left = Divider.createLine(frame)
  local right = Divider.createLine(frame)
  right:SetPoint("LEFT", left, "RIGHT", 0, 0)

  return {
    left = left,
    right = right,
    setWidth = function(width)
      left:SetWidth(width / 2)
      right:SetWidth(width / 2)
    end,
    applyTheme = function(activeTheme)
      Divider.paint(left, right, activeTheme)
    end,
  }
end

ns.SettingsControlsDivider = Divider
return Divider
