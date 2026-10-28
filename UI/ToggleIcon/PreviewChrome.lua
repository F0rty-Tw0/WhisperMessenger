local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- The message preview's frame and border. Under the Native WoW HUD it wears
-- the game's tooltip border (art only: the colour presets still tint its fill,
-- opaque as the game's tooltips are); otherwise (or when this client lacks the
-- template) a plain frame with WM's rounded background.
local PreviewChrome = {}

local TOOLTIP_TEMPLATE = "TooltipBackdropTemplate"
local CORNER_RADIUS = 4
-- The template's own fill alpha (Blizzard_SharedXML/SharedTooltipTemplates.lua:232,
-- backdropColorAlpha or 1). A preset's see-through alpha let bright ground wash out
-- class-coloured names and item links.
local TOOLTIP_FILL_ALPHA = 1

-- A client without the template may log and return a plain frame instead of throwing.
local function hasTooltipParts(frame)
  return frame.NineSlice ~= nil or frame.SetBackdropColor ~= nil
end

-- Same setColor shape as the rounded background, painting the tooltip's fill
-- in the colour's RGB at the tooltip's alpha.
local function tooltipFill(frame)
  local function setColor(color)
    if not color then
      return
    end
    local r, g, b, a = color[1], color[2], color[3], TOOLTIP_FILL_ALPHA
    if frame.SetBackdropColor then
      frame:SetBackdropColor(r, g, b, a)
    elseif frame.NineSlice and frame.NineSlice.SetCenterColor then
      frame.NineSlice:SetCenterColor(r, g, b, a)
    end
  end
  return { setColor = setColor }
end

-- Returns the preview frame and an object whose setColor tints its fill.
function PreviewChrome.Create(factory, parent)
  local frame
  if Hud.IsOn() then
    local ok, created = pcall(factory.CreateFrame, "Frame", nil, parent, TOOLTIP_TEMPLATE)
    if ok and created then
      if hasTooltipParts(created) then
        return created, tooltipFill(created)
      end
      frame = created
    end
  end
  frame = frame or factory.CreateFrame("Frame", nil, parent)
  return frame, UIHelpers.createRoundedBackground(frame, CORNER_RADIUS)
end

-- A label that never wraps or grows past one line.
function PreviewChrome.SingleLine(label)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  if label.SetMaxLines then
    label:SetMaxLines(1)
  end
end

ns.ToggleIconPreviewChrome = PreviewChrome

return PreviewChrome
