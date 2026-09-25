local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Modern-skin "X" button (search clear, reply banner close): a grey glyph
-- that brightens on hover. The caller anchors it and sets OnClick.
local CloseGlyphButton = {}

-- Close-style hover red, shared with the widget's message preview dismiss.
CloseGlyphButton.DANGER_HOVER = { 1.0, 0.35, 0.35, 1.0 }

-- theme: optional, defaults to Theme; colours are read at hover time.
-- options.danger: the glyph turns red on hover instead of brightening.
function CloseGlyphButton.Create(factory, parent, size, theme, options)
  theme = theme or Theme
  local danger = options ~= nil and options.danger == true
  local button = factory.CreateFrame("Button", nil, parent)
  button:SetSize(size, size)
  button:EnableMouse(true)

  local label = button:CreateFontString(nil, "OVERLAY", theme.FONTS.contact_name)
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  label:SetText("X")
  UIHelpers.setTextColor(label, theme.COLORS.text_secondary)
  button:SetScript("OnEnter", function()
    UIHelpers.setTextColor(label, danger and CloseGlyphButton.DANGER_HOVER or theme.COLORS.text_primary)
  end)
  button:SetScript("OnLeave", function()
    UIHelpers.setTextColor(label, theme.COLORS.text_secondary)
  end)
  button.label = label
  return button
end

ns.CloseGlyphButton = CloseGlyphButton
return CloseGlyphButton
