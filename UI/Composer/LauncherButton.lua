local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")

-- Square, backgroundless composer button that opens a picker (emoji, quick
-- replies): rounded highlight on hover and a tooltip naming the action.
-- spec = { tooltip = <localization key>, hint = <optional localization key
-- for a grey second line>, isEnabled = fn, onClick = fn }
local LauncherButton = {}

function LauncherButton.Create(factory, parent, spec)
  local button = factory.CreateFrame("Button", nil, parent)
  local bg = UIHelpers.createRoundedBackground(button, 8)
  button.bg = bg
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.icon = icon

  function button.paint(hovered)
    bg.setColor(hovered and PickerStyles.HighlightColor() or UIHelpers.TRANSPARENT)
  end

  button:SetScript("OnEnter", function(self)
    if spec.isEnabled() then
      button.paint(true)
      PickerStyles.ShowTooltipText(self, Localization.Text(spec.tooltip), spec.hint and Localization.Text(spec.hint))
    end
  end)
  button:SetScript("OnLeave", function()
    button.paint(false)
    PickerStyles.HideTooltip()
  end)
  button:SetScript("OnClick", function()
    PickerStyles.HideTooltip()
    if spec.isEnabled() then
      spec.onClick()
    end
  end)

  button.paint(false)
  return button
end

ns.ComposerLauncherButton = LauncherButton
return LauncherButton
