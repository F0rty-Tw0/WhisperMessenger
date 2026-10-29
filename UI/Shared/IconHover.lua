local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

-- Hover for the widget and the minimap button: a copy of the logo added on
-- top in the theme's accent, so the logo lights up in the theme's color.
-- (It replaces the old hover, which recolored the disc behind the logo.)
local IconHover = {}

IconHover.STRENGTH = 0.45 -- the glow's opacity

-- frame: the button; logo: its logo texture. Returns { glow, set(on) }.
function IconHover.Create(frame, logo)
  local glow = frame:CreateTexture(nil, "ARTWORK", nil, 7)
  glow:SetAllPoints(logo)
  if glow.SetBlendMode then
    glow:SetBlendMode("ADD")
  end
  glow:Hide()

  local function set(on)
    if not on then
      glow:Hide()
      return
    end
    -- whichever logo is showing (full, or rimless inside a ring)
    glow:SetTexture(logo:GetTexture())
    local a = Theme.COLORS.accent
    applyVertexColor(glow, { a[1], a[2], a[3], IconHover.STRENGTH })
    glow:Show()
  end

  return { glow = glow, set = set }
end

ns.IconHover = IconHover
return IconHover
