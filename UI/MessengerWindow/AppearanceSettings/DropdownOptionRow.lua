local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

-- One row of the modern dropdown's open list: a choice or a group header.
local DropdownOptionRow = {}

function DropdownOptionRow.Paint(optionButton, palette, selectedKey)
  if optionButton._header then
    applyColorTexture(optionButton.bg, palette.bg)
    UIHelpers.setTextColor(optionButton.label, Theme.COLORS.text_secondary)
  elseif optionButton._key == selectedKey then
    applyColorTexture(optionButton.bg, palette.bgActive)
    UIHelpers.setTextColor(optionButton.label, palette.textActive)
  elseif optionButton._hovered then
    applyColorTexture(optionButton.bg, palette.bgHover)
    UIHelpers.setTextColor(optionButton.label, palette.textHover)
  else
    applyColorTexture(optionButton.bg, palette.bg)
    UIHelpers.setTextColor(optionButton.label, palette.text)
  end
end

function DropdownOptionRow.RepaintAll(optionButtons, palette, selectedKey)
  for _, optionButton in ipairs(optionButtons) do
    DropdownOptionRow.Paint(optionButton, palette, selectedKey)
  end
end

-- `getSelected` is read on every hover so the row paints the live selection;
-- `onPick(key)` runs on a click on a choice, never on a header.
function DropdownOptionRow.Create(factory, content, palette, getSelected, onPick)
  local optionButton = factory.CreateFrame("Button", nil, content)
  local bg = optionButton:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(optionButton)

  local optionLabel = optionButton:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  optionLabel:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
  optionLabel:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
  optionLabel:SetJustifyH("LEFT")

  optionButton.bg = bg
  optionButton.label = optionLabel
  optionButton._hovered = false

  optionButton:SetScript("OnClick", function()
    if optionButton._header then
      return
    end
    onPick(optionButton._key)
  end)
  optionButton:SetScript("OnEnter", function()
    optionButton._hovered = true
    DropdownOptionRow.Paint(optionButton, palette, getSelected())
  end)
  optionButton:SetScript("OnLeave", function()
    optionButton._hovered = false
    DropdownOptionRow.Paint(optionButton, palette, getSelected())
  end)

  return optionButton
end

ns.MessengerWindowDropdownOptionRow = DropdownOptionRow
return DropdownOptionRow
