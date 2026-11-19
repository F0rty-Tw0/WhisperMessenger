local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Desaturation = ns.ToggleIconDesaturation or require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local applyVertexColor = UIHelpers.applyVertexColor

-- The widget's and the minimap's accent back bubble, drawn just under the
-- white front glyph.
local AccentGlyph = {}

AccentGlyph.TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_back.png"

-- The back bubble, drawn just under `glyph` and sized with it.
-- apply(desaturated, hovered) shows it in the accent color, or the circle's
-- gray (DESAT_BACK, on every shape) while the button is desaturated and not
-- hovered.
function AccentGlyph.Create(frame, glyph)
  local texture = frame:CreateTexture(nil, "ARTWORK", nil, -1)
  texture:SetAllPoints(glyph)
  texture:SetTexture(AccentGlyph.TEXTURE)

  local function apply(desaturated, hovered)
    if texture.Show then
      texture:Show()
    end
    local color = desaturated and not hovered and Desaturation.DESAT_BACK or Theme.COLORS.accent
    applyVertexColor(texture, color)
  end

  local accentGlyph = { texture = texture, apply = apply }

  return accentGlyph
end

ns.ToggleIconAccentGlyph = AccentGlyph
return AccentGlyph
