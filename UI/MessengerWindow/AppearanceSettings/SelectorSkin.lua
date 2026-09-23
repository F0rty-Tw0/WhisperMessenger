local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")

-- Choice-button sizing and look. Buttons are never narrower than their
-- widest label plus PADDING_X on each side, so long or localized labels and
-- bigger fonts keep breathing room. Subtle surface at rest, accent tint +
-- accent underline when selected, faint white wash on hover.
local SelectorSkin = {}

SelectorSkin.PADDING_X = 12
SelectorSkin.MIN_BUTTON_WIDTH = 40
SelectorSkin.UNDERLINE_HEIGHT = 2

function SelectorSkin.FitWidth(buttons)
  local widest = 0
  for _, btn in ipairs(buttons) do
    local width = btn.label and btn.label.GetStringWidth and btn.label:GetStringWidth() or 0
    if width > widest then
      widest = width
    end
  end
  return math.max(SelectorSkin.MIN_BUTTON_WIDTH, math.ceil(widest + 2 * SelectorSkin.PADDING_X))
end

function SelectorSkin.Attach(btn)
  local hover = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
  hover:SetAllPoints(btn)
  hover:Hide()
  local underline = btn:CreateTexture(nil, "ARTWORK")
  underline:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
  underline:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
  underline:SetHeight(SelectorSkin.UNDERLINE_HEIGHT)
  underline:Hide()
  btn.hover = hover
  btn.hoverFade = HoverFade.Attach(hover)
  btn.underline = underline
end

function SelectorSkin.Paint(btn, selected, hovered)
  local colors = Theme.COLORS
  UIHelpers.applyColorTexture(btn.bg, selected and colors.option_button_active or colors.option_button_bg)
  UIHelpers.applyColorTexture(btn.underline, colors.accent_bar)
  btn.underline:SetShown(selected)
  btn.hoverFade.paintColor(colors.bg_contact_hover)
  btn.hoverFade.set(hovered and not selected)
  UIHelpers.setTextColor(btn.label, (selected or hovered) and colors.text_primary or colors.text_secondary)
end

ns.MessengerWindowSelectorSkin = SelectorSkin
return SelectorSkin
