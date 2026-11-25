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
-- paint flat fills; native rows (Native WoW HUD) look like WM's own menus:
-- the dropdown hover highlight and a check mark by the chosen option.
local DropdownOptionRow = {}

local LABEL_INSET = 8
-- The game's NORMAL_FONT_COLOR, for a client that lacks the global.
local SELECTED_GOLD = { 1, 0.82, 0, 1 }

local function selectedTextColor()
  local color = _G.NORMAL_FONT_COLOR
  if type(color) == "table" and color.r then
    return { color.r, color.g, color.b, 1 }
  end
  return SELECTED_GOLD
end

-- Moves the label only when the inset changes.
local function setLabelInset(optionButton, inset)
  if optionButton._labelInset == inset then
    return
  end
  optionButton._labelInset = inset
  local label = optionButton.label
  label:ClearAllPoints()
  label:SetPoint("LEFT", optionButton, "LEFT", inset, 0)
  label:SetPoint("RIGHT", optionButton, "RIGHT", -LABEL_INSET, 0)
end

-- Native: the check shows on the selected choice only, and every choice's
-- label clears it so the labels line up; headers start at the edge. Hover is
-- the button's highlight texture, so it leaves the text alone. Headers get
-- no hover art, so they don't look clickable; a pooled row can switch
-- between header and choice, hence set on every paint.
local function paintNative(optionButton, palette, selectedKey)
  local selected = not optionButton._header and optionButton._key == selectedKey
  optionButton._check:SetShown(selected)
  optionButton._highlight:SetAlpha(optionButton._header and 0 or 1)
  setLabelInset(optionButton, optionButton._header and LABEL_INSET or PickerPopup.CHECK_LABEL_PAD)
  if optionButton._header then
    UIHelpers.setTextColor(optionButton.label, Theme.COLORS.text_secondary)
  elseif selected then
    UIHelpers.setTextColor(optionButton.label, selectedTextColor())
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
    -- No selection bar: the check marks the choice.
    bg:Hide()
    local check = optionButton:CreateTexture(nil, "ARTWORK")
    check:SetTexture(PickerPopup.CHECK_TEXTURE)
    check:SetSize(PickerPopup.CHECK_SIZE, PickerPopup.CHECK_SIZE)
    check:SetPoint("LEFT", optionButton, "LEFT", PickerPopup.CHECK_INSET, 0)
    check:Hide()
    optionButton._check = check
    optionButton._highlight = NativeArt.AddHighlight(optionButton, NativeArt.LIST_HOVER)
  end

  local fontObject = optionButton._native and PickerPopup.MENU_FONT or Theme.FONTS.system_text
  local optionLabel = optionButton:CreateFontString(nil, "OVERLAY", fontObject)
  optionLabel:SetJustifyH("LEFT")
  -- The check takes 16px of the fixed row width; a long name truncates
  -- instead of wrapping into the next row.
  if optionButton._native and optionLabel.SetWordWrap then
    optionLabel:SetWordWrap(false)
  end

  optionButton.bg = bg
  optionButton.label = optionLabel
  optionButton._hovered = false
  setLabelInset(optionButton, optionButton._native and PickerPopup.CHECK_LABEL_PAD or LABEL_INSET)

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
