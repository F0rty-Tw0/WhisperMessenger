local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")

-- Title-bar icon buttons: no fill, no border, a bundled line icon in
-- text_secondary (text_primary when hovered/active) and a faint white circle
-- that fades in behind it on hover.
local IconButtonStyle = {}

local CIRCLE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local HOVER_CIRCLE = { 1, 1, 1, 0.06 }
local DANGER_GLYPH = { 0.95, 0.36, 0.36, 1 }

-- Create the hover circle once. Call before creating the glyph texture so
-- the glyph stays the button's last textured child.
function IconButtonStyle.Attach(button, bg)
  local circle = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  circle:SetAllPoints(button)
  circle:SetTexture(CIRCLE_TEXTURE)
  circle:Hide()
  local fade = HoverFade.Attach(circle)
  fade.paintVertex(HOVER_CIRCLE)
  button._wmHoverCircle = circle
  button._wmHoverFade = fade
  button._wmBg = bg
  return circle
end

-- Registers the glyph texture and sets its bundled icon.
function IconButtonStyle.SetGlyph(button, glyph, texturePath)
  button._wmGlyph = glyph
  if glyph.SetTexture then
    glyph:SetTexture(texturePath)
  end
end

-- Paints the button and returns the glyph color. `danger` turns the hovered
-- glyph red (close button).
function IconButtonStyle.Paint(button, emphasized, colors, danger)
  UIHelpers.applyColorTexture(button._wmBg, UIHelpers.TRANSPARENT)
  button._wmHoverFade.set(emphasized == true)
  if not emphasized then
    return colors.text_secondary
  end
  return danger and DANGER_GLYPH or colors.text_primary
end

ns.MessengerWindowChromeBuilderIconButtonStyle = IconButtonStyle
return IconButtonStyle
