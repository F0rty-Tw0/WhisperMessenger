local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")

-- Square, backgroundless composer button that opens a picker (emoji, quick
-- replies): rounded highlight on hover (the game's mouse-over glow under the
-- Native WoW HUD) and a tooltip naming the action.
-- spec = { tooltip = <localization key>, hint = <optional localization key
-- for a grey second line>, isEnabled = fn, onClick = fn }
local LauncherButton = {}

function LauncherButton.Create(factory, parent, spec)
  local button = factory.CreateFrame("Button", nil, parent)
  if Hud.IsOn() then
    local glow = NativeArt.CreateIconGlow(button)
    function button.paint(hovered)
      glow:SetShown(hovered == true)
    end
  else
    local bg = UIHelpers.createRoundedBackground(button, 8)
    button.bg = bg
    function button.paint(hovered)
      bg.setColor(hovered and PickerStyles.HighlightColor() or UIHelpers.TRANSPARENT)
    end
  end
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.icon = icon

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
