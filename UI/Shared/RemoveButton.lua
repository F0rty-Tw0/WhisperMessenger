local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")

-- Small trash-icon button for list rows on the settings pages: dims to the
-- icon colour, turns red on hover and shows a "Remove" tooltip (or
-- tooltipKey, e.g. "Unblock").
local RemoveButton = {}

RemoveButton.SIZE = 16

function RemoveButton.Paint(button, hovered)
  UIHelpers.applyVertexColor(button.icon, hovered and Theme.COLORS.danger_text or Theme.COLORS.action_icon or Theme.COLORS.text_secondary)
end

function RemoveButton.Create(factory, parent, onClick, tooltipKey)
  local button = factory.CreateFrame("Button", nil, parent)
  button:SetSize(RemoveButton.SIZE, RemoveButton.SIZE)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints(button)
  button.icon:SetTexture(Theme.TEXTURES.trash_icon)
  RemoveButton.Paint(button, false)
  button:SetScript("OnEnter", function(self)
    RemoveButton.Paint(self, true)
    PickerStyles.ShowTooltipText(self, Localization.Text(tooltipKey or "Remove"))
  end)
  button:SetScript("OnLeave", function(self)
    RemoveButton.Paint(self, false)
    PickerStyles.HideTooltip()
  end)
  button:SetScript("OnClick", function()
    PickerStyles.HideTooltip()
    onClick()
  end)
  return button
end

ns.RemoveButton = RemoveButton
return RemoveButton
