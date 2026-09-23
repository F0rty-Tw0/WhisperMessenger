local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")
local Shapes = ns.UIHelpersShapes or require("WhisperMessenger.UI.Helpers.Shapes")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")

-- Outline ("ghost") look for secondary buttons: neutral
-- 1px border, no fill, neutral text, faint neutral fill fading in on hover.
-- Parts are created once per button; Paint only recolors and toggles.
-- `danger` ghosts (destructive actions) swap the neutral colours for the
-- danger red: red text, soft red outline, faint red wash on hover.
local GhostButton = {}

GhostButton.DANGER_BORDER_ALPHA = 0.45
GhostButton.DANGER_WASH_ALPHA = 0.12

function GhostButton.Attach(button, opts)
  local hover = button:CreateTexture(nil, "ARTWORK")
  hover:SetAllPoints(button)
  hover:Hide()
  local border = Shapes.createBorderBox(button, Theme.COLORS.ghost_button_border, 1, "BORDER")
  return { hover = hover, hoverFade = HoverFade.Attach(hover), border = border, danger = opts and opts.danger == true }
end

local NO_SIDES = {}

function GhostButton.SetShown(ghost, shown)
  if shown then
    Base.setBorderEdgesShown(ghost.border, nil)
    return
  end
  Base.setBorderEdgesShown(ghost.border, NO_SIDES)
  ghost.hoverFade.set(false)
end

local function withAlpha(color, alpha)
  return { color[1], color[2], color[3], alpha }
end

function GhostButton.Paint(ghost, label, hovered)
  local colors = Theme.COLORS
  GhostButton.SetShown(ghost, true)
  if ghost.danger then
    local red = colors.danger_text
    Base.applyBorderBoxColor(ghost.border, withAlpha(red, GhostButton.DANGER_BORDER_ALPHA))
    ghost.hoverFade.paintColor(withAlpha(red, GhostButton.DANGER_WASH_ALPHA))
    Base.setTextColor(label, red)
  else
    Base.applyBorderBoxColor(ghost.border, colors.ghost_button_border)
    ghost.hoverFade.paintColor(colors.ghost_button_fill_hover)
    Base.setTextColor(label, colors.ghost_button_text)
  end
  ghost.hoverFade.set(hovered)
end

ns.UIHelpersGhostButton = GhostButton
return GhostButton
