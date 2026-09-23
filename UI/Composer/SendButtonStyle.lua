local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")

-- Send button paint: the bundled paper-plane glyph tinted with the accent
-- (no border, no fill), a faint neutral circle fading in on hover and a
-- slightly brighter glyph. Returns paint(disabled, hovered).
local SendButtonStyle = {}

local ICON_SIZE = 18
local SEND_ICON_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\send.png"
-- Neutral grey at half alpha for the disabled glyph, whatever the preset.
local DISABLED_GLYPH = { 0.62, 0.62, 0.62, 0.5 }
-- How far the hovered glyph moves toward white.
local HOVER_BRIGHTEN = 0.25
local HOVER_CIRCLE_SIZE = 26
local HOVER_CIRCLE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

function SendButtonStyle.Create(button)
  local circle = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  circle:SetSize(HOVER_CIRCLE_SIZE, HOVER_CIRCLE_SIZE)
  circle:SetPoint("CENTER", button, "CENTER", 0, 0)
  circle:SetTexture(HOVER_CIRCLE_TEXTURE)
  circle:Hide()
  local circleFade = HoverFade.Attach(circle)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  icon:SetTexture(SEND_ICON_TEXTURE)
  icon:Show()
  local hoverGlyph = { 1, 1, 1, 1 }

  return function(disabled, hovered)
    local colors = Theme.COLORS
    local glyph = colors.accent
    if disabled then
      glyph = DISABLED_GLYPH
    elseif hovered then
      for i = 1, 3 do
        hoverGlyph[i] = glyph[i] + (1 - glyph[i]) * HOVER_BRIGHTEN
      end
      glyph = hoverGlyph
    end
    UIHelpers.applyVertexColor(icon, glyph)
    circleFade.paintVertex(colors.bg_contact_hover)
    circleFade.set(hovered and not disabled)
  end
end

ns.ComposerSendButtonStyle = SendButtonStyle
return SendButtonStyle
