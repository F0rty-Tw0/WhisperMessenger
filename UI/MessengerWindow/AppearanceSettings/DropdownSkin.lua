local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Closed-dropdown look: the same softly rounded input surface as the
-- contacts search field, a down chevron on the right (the bundled back glyph
-- rotated a quarter turn via tex coords, no new media) and a faint wash on
-- hover.
local DropdownSkin = {}

DropdownSkin.CHEVRON_TEXTURE = Theme.TEXTURES.title_back_icon
DropdownSkin.CHEVRON_SIZE = 10
DropdownSkin.CHEVRON_INSET = 8
DropdownSkin.RADIUS = 6
DropdownSkin.LABEL_INSET = 8
DropdownSkin.LABEL_CHEVRON_GAP = 6

-- Palette from theme colours; `overrides` entries win when present.
function DropdownSkin.Palette(colors, overrides)
  overrides = overrides or {}
  return {
    bg = overrides.bg or colors.option_button_bg,
    bgHover = overrides.bgHover or colors.option_button_hover,
    bgActive = overrides.bgActive or colors.option_button_active or colors.option_button_hover,
    text = overrides.text or colors.option_button_text,
    textHover = overrides.textHover or colors.option_button_text_hover,
    textActive = overrides.textActive or colors.option_button_text_active or colors.text_primary,
  }
end

local function setRoundedShown(rounded, shown)
  for _, part in ipairs(rounded.fills) do
    part:SetShown(shown)
  end
  for _, part in ipairs(rounded.corners) do
    part:SetShown(shown)
  end
end

function DropdownSkin.Attach(button, label)
  local surface = UIHelpers.createRoundedBackground(button, DropdownSkin.RADIUS, "BACKGROUND", 1)
  local hover = UIHelpers.createRoundedBackground(button, DropdownSkin.RADIUS, "BACKGROUND", 2)
  local chevron = button:CreateTexture(nil, "ARTWORK")
  chevron:SetSize(DropdownSkin.CHEVRON_SIZE, DropdownSkin.CHEVRON_SIZE)
  chevron:SetPoint("RIGHT", button, "RIGHT", -DropdownSkin.CHEVRON_INSET, 0)
  chevron:SetTexture(DropdownSkin.CHEVRON_TEXTURE)
  -- "<" glyph turned 90 degrees counter-clockwise so it points down.
  chevron:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
  chevron:Show()
  setRoundedShown(surface, true)
  setRoundedShown(hover, false)
  -- Value text stops short of the chevron.
  label:SetPoint("LEFT", button, "LEFT", DropdownSkin.LABEL_INSET, 0)
  label:SetPoint("RIGHT", button, "RIGHT", -(DropdownSkin.CHEVRON_INSET + DropdownSkin.CHEVRON_SIZE + DropdownSkin.LABEL_CHEVRON_GAP), 0)
  return { surface = surface, hover = hover, chevron = chevron }
end

function DropdownSkin.Paint(skin, label, hovered)
  local colors = Theme.COLORS
  setRoundedShown(skin.hover, hovered)
  skin.surface.setColor(colors.bg_input)
  skin.hover.setColor(colors.bg_contact_hover)
  UIHelpers.applyVertexColor(skin.chevron, hovered and colors.text_primary or colors.text_secondary)
  UIHelpers.setTextColor(label, colors.text_primary)
end

ns.MessengerWindowDropdownSkin = DropdownSkin
return DropdownSkin
