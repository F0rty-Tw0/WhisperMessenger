local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local CloseGlyphButton = ns.CloseGlyphButton or require("WhisperMessenger.UI.Shared.CloseGlyphButton")
local PreviewMetrics = ns.ToggleIconPreviewMetrics or require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local applyVertexColor = UIHelpers.applyVertexColor
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local DISMISS_COLOR_HOVER = CloseGlyphButton.DANGER_HOVER
local DISMISS_BG_HOVER = { 0.85, 0.15, 0.15, 0.35 }
local DISMISS_BG_REST = { 0, 0, 0, 0 }

-- The preview card's top-right x. The card sets OnClick itself.
local PreviewDismissButton = {}

function PreviewDismissButton.Create(factory, previewFrame, theme)
  local button = factory.CreateFrame("Button", nil, previewFrame)
  button:SetSize(PreviewMetrics.DISMISS_SIZE, PreviewMetrics.DISMISS_SIZE)
  button:SetPoint("TOPRIGHT", previewFrame, "TOPRIGHT", -PreviewMetrics.DISMISS_INSET, -PreviewMetrics.DISMISS_INSET)
  if button.EnableMouse then
    button:EnableMouse(true)
  end
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(button)
  applyVertexColor(bg, DISMISS_BG_REST)
  local label = button:CreateFontString(nil, "OVERLAY")
  setFontObject(label, theme.FONTS.close_glyph or theme.FONTS.header_name)
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  label:SetText("×")
  -- Neutral at rest; red only on hover so the toast does not shout.
  setTextColor(label, theme.COLORS.text_secondary)

  if button.SetScript then
    button:SetScript("OnEnter", function()
      setTextColor(label, DISMISS_COLOR_HOVER)
      applyVertexColor(bg, DISMISS_BG_HOVER)
    end)
    button:SetScript("OnLeave", function()
      setTextColor(label, theme.COLORS.text_secondary)
      applyVertexColor(bg, DISMISS_BG_REST)
    end)
  end

  local function applyTheme(activeTheme)
    theme = activeTheme or theme
    setTextColor(label, theme.COLORS.text_secondary)
  end

  return { button = button, label = label, applyTheme = applyTheme }
end

ns.ToggleIconPreviewDismissButton = PreviewDismissButton

return PreviewDismissButton
