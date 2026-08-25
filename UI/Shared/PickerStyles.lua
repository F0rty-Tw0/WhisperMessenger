local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local PickerStyles = {}

function PickerStyles.ApplyColor(texture, color)
  if texture and type(texture.SetColorTexture) == "function" then
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  end
end

function PickerStyles.ShowTooltipText(owner, text)
  local tooltip = _G.GameTooltip
  if type(tooltip) ~= "table" then
    return
  end
  if type(tooltip.SetOwner) == "function" then
    tooltip:SetOwner(owner, "ANCHOR_TOP")
  end
  if type(tooltip.SetText) == "function" then
    tooltip:SetText(text)
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
end

function PickerStyles.ShowTooltip(owner, key)
  PickerStyles.ShowTooltipText(owner, ":" .. key .. ":")
end

function PickerStyles.HideTooltip()
  local tooltip = _G.GameTooltip
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

function PickerStyles.BackgroundColor()
  local color = Theme.COLORS.bg_header or Theme.COLORS.bg_composer or { 0.05, 0.06, 0.08, 1 }
  return { color[1], color[2], color[3], 0.96 }
end

function PickerStyles.BorderColor()
  local color = Theme.COLORS.contacts_border_right or Theme.COLORS.divider or { 0.2, 0.2, 0.2, 1 }
  return { color[1], color[2], color[3], 1 }
end

function PickerStyles.HighlightColor(alpha)
  local color = Theme.COLORS.option_button_hover or Theme.COLORS.bg_contact_hover or { 0.2, 0.5, 0.8, 1 }
  return { color[1], color[2], color[3], alpha ~= nil and alpha or (color[4] or 1) }
end

function PickerStyles.ApplyPanelTheme(frame, border)
  PickerStyles.ApplyColor(frame._background, PickerStyles.BackgroundColor())
  if border and type(UIHelpers.applyBorderBoxColor) == "function" then
    UIHelpers.applyBorderBoxColor(border, PickerStyles.BorderColor())
  end
end

ns.PickerStyles = PickerStyles
return PickerStyles
