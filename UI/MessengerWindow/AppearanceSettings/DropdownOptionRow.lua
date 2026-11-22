local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")
local applyColorTexture = UIHelpers.applyColorTexture

-- One row of WM's own dropdown list: a choice or a group header. Modern rows
-- paint flat fills; native rows (Native WoW HUD) use the game's list art:
-- the dropdown hover highlight and the quest log's selected entry.
local DropdownOptionRow = {}

-- Native: the selection art shows on the selected choice only; hover is the
-- button's highlight texture, so it leaves the text alone. Headers get no
-- hover art, so they don't look clickable; a pooled row can switch between
-- header and choice, hence set on every paint.
local function paintNative(optionButton, palette, selectedKey)
  local selected = not optionButton._header and optionButton._key == selectedKey
  optionButton.bg:SetShown(selected)
  optionButton._highlight:SetAlpha(optionButton._header and 0 or 1)
  if optionButton._header then
    UIHelpers.setTextColor(optionButton.label, Theme.COLORS.text_secondary)
  elseif selected then
    UIHelpers.setTextColor(optionButton.label, palette.textActive)
  else
    UIHelpers.setTextColor(optionButton.label, palette.text)
  end
end

function DropdownOptionRow.Paint(optionButton, palette, selectedKey)
  if optionButton._native then
    paintNative(optionButton, palette, selectedKey)
  elseif optionButton._header then
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
-- `onPick(key)` runs on a click on a choice, never on a header. `native`
-- (optional) gives the row the Native WoW HUD look.
function DropdownOptionRow.Create(factory, content, palette, getSelected, onPick, native)
  local optionButton = factory.CreateFrame("Button", nil, content)
  local bg = optionButton:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(optionButton)
  optionButton._native = native == true
  if optionButton._native then
    -- Dimmed like every native list selection (full-strength additive art glares).
    NativeArt.Set(bg, NativeArt.LIST_SELECTED)
    bg:SetVertexColor(1, 1, 1, NativeArt.LIST_SELECTED_ALPHA)
    bg:Hide()
    optionButton._highlight = NativeArt.AddHighlight(optionButton, NativeArt.LIST_HOVER)
  end

  local fontObject = optionButton._native and PickerPopup.MENU_FONT or Theme.FONTS.system_text
  local optionLabel = optionButton:CreateFontString(nil, "OVERLAY", fontObject)
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
