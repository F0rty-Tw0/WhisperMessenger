local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeControls = ns.UIHelpersNativeControls or require("WhisperMessenger.UI.Helpers.NativeControls")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")

-- Popup with two labelled one-line inputs (the game's StaticPopup has only
-- one edit box): an optional first field and a required second one. The
-- modern look matches the addon's text popups; under the Native WoW HUD it
-- uses Blizzard's dialog border, input boxes and panel buttons.
local TwoFieldDialog = {}

TwoFieldDialog.FRAME_NAME = "WhisperMessengerTwoFieldDialog"

local WIDTH = 380
local PADDING = 18
local TITLE_SPACE = 30
local LABEL_GAP = 4
local FIELD_GAP = 10
local INPUT_HEIGHT = 24
local LABEL_HEIGHT = 14
-- InputBoxTemplate's art reaches past the box's left edge.
local NATIVE_INPUT_INSET = 6
local BUTTON_WIDTH = 130
local BUTTON_GAP = 10
local INPUT_RADIUS = 6
local FRAME_RADIUS = 10
-- Blizzard's own text colours for the Native WoW HUD look.
local NATIVE_TITLE_COLOR = { 1, 0.82, 0, 1 }
local NATIVE_TEXT_COLOR = { 1, 1, 1, 1 }
local NATIVE_HINT_COLOR = { 0.8, 0.8, 0.8, 1 }
local NATIVE_BORDER_TEMPLATE = "DialogBorderTemplate"
-- Blizzard's dialog background is see-through; a dark fill under it keeps
-- the world from showing through. Inset to sit inside the border art.
local NATIVE_FILL_COLOR = { 0, 0, 0, 0.9 }
local NATIVE_FILL_INSET = 7
local NATIVE_INPUT_TEMPLATE = "InputBoxTemplate"

-- One dialog per frame factory, reused on every Show.
local dialogs = setmetatable({}, { __mode = "k" })

local function trimmed(box)
  return string.match(box:GetText() or "", "^%s*(.-)%s*$")
end

-- A missing template is skipped where the client can tell; elsewhere the
-- pcall in createTemplatedFrame is the guard.
local function hasTemplate(name)
  local xmlUtil = _G.C_XMLUtil
  if type(xmlUtil) ~= "table" or type(xmlUtil.GetTemplateInfo) ~= "function" then
    return true
  end
  local ok, info = pcall(xmlUtil.GetTemplateInfo, name)
  return ok and info ~= nil
end

local function nativeFrame(factory, frameType, parent, template)
  if not StyledTextInputPopup.nativeChrome or not hasTemplate(template) then
    return nil
  end
  return UIHelpers.createTemplatedFrame(factory, frameType, nil, parent, template)
end

local function createText(parent, font)
  local label = parent:CreateFontString(nil, "OVERLAY", font)
  label:SetJustifyH("LEFT")
  return label
end

local function createInput(factory, body)
  local box = nativeFrame(factory, "EditBox", body, NATIVE_INPUT_TEMPLATE)
  local inset = box and NATIVE_INPUT_INSET or 0
  if box == nil then
    box = factory.CreateFrame("EditBox", nil, body)
    UIHelpers.setFontObject(box, Theme.FONTS.composer_input)
    box.background = UIHelpers.createRoundedBackground(box, INPUT_RADIUS)
    if box.SetTextInsets then
      box:SetTextInsets(8, 8, 0, 0)
    end
  end
  box.inset = inset
  box:SetSize(WIDTH - PADDING * 2 - inset, INPUT_HEIGHT)
  if box.SetAutoFocus then
    box:SetAutoFocus(false)
  end
  return box
end

local function createButton(factory, body)
  local height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT
  if StyledTextInputPopup.nativeChrome then
    local native = NativeControls.CreateButton(factory, body, "", BUTTON_WIDTH, height)
    if native then
      return native
    end
  end
  return UIHelpers.createOptionButton(factory, body, "", SettingsControls.OptionButtonColors(Theme), { height = height, width = BUTTON_WIDTH })
end

-- Native art sits on its own child so the content frame draws above it.
local function createBackground(factory, frame)
  local border = nativeFrame(factory, "Frame", frame, NATIVE_BORDER_TEMPLATE)
  if border then
    border:SetAllPoints(frame)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", NATIVE_FILL_INSET, -NATIVE_FILL_INSET)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -NATIVE_FILL_INSET, NATIVE_FILL_INSET)
    local c = NATIVE_FILL_COLOR
    fill:SetColorTexture(c[1], c[2], c[3], c[4])
    frame.nativeFill = fill
    return nil
  end
  local background = UIHelpers.createRoundedBackground(frame, FRAME_RADIUS)
  local outline = UIHelpers.createBorderBox(frame, Theme.COLORS.divider, 1, "BORDER")
  return function()
    if background and background.setColor then
      background.setColor(Theme.COLORS.bg_primary)
    end
    UIHelpers.applyBorderBoxColor(outline, Theme.COLORS.divider)
  end
end

local function layout(dialog)
  local body = dialog.body
  dialog.title:SetPoint("TOP", body, "TOP", 0, -PADDING)
  dialog.firstLabel:SetPoint("TOPLEFT", body, "TOPLEFT", PADDING, -(PADDING + TITLE_SPACE))
  dialog.firstInput:SetPoint("TOPLEFT", dialog.firstLabel, "BOTTOMLEFT", dialog.firstInput.inset, -LABEL_GAP)
  dialog.secondLabel:SetPoint("TOPLEFT", dialog.firstLabel, "BOTTOMLEFT", 0, -(LABEL_GAP + INPUT_HEIGHT + FIELD_GAP))
  dialog.secondInput:SetPoint("TOPLEFT", dialog.secondLabel, "BOTTOMLEFT", dialog.secondInput.inset, -LABEL_GAP)
  dialog.hint:SetPoint("TOPLEFT", dialog.secondLabel, "BOTTOMLEFT", 0, -(LABEL_GAP * 2 + INPUT_HEIGHT))
  dialog.hint:SetWidth(WIDTH - PADDING * 2)
  dialog.hint:SetWordWrap(true)
  dialog.acceptButton:SetPoint("BOTTOMRIGHT", body, "BOTTOM", -BUTTON_GAP / 2, PADDING)
  dialog.cancelButton:SetPoint("BOTTOMLEFT", body, "BOTTOM", BUTTON_GAP / 2, PADDING)
end

local function wireKeys(dialog)
  local first, second = dialog.firstInput, dialog.secondInput
  local function close()
    dialog:Hide()
  end
  local function focus(box)
    return function()
      box:SetFocus()
    end
  end
  first:SetScript("OnEnterPressed", focus(second))
  first:SetScript("OnTabPressed", focus(second))
  first:SetScript("OnEscapePressed", close)
  second:SetScript("OnEnterPressed", dialog.accept)
  second:SetScript("OnTabPressed", focus(first))
  second:SetScript("OnEscapePressed", close)
  second:SetScript("OnTextChanged", dialog.refreshAccept)
  dialog.acceptButton:SetScript("OnClick", dialog.accept)
  dialog.cancelButton:SetScript("OnClick", close)
  dialog:SetScript("OnHide", function()
    first:ClearFocus()
    second:ClearFocus()
  end)
end

local function build(factory)
  local dialog = factory.CreateFrame("Frame", TwoFieldDialog.FRAME_NAME, _G.UIParent)
  dialog:SetFrameStrata("DIALOG")
  if dialog.SetToplevel then
    dialog:SetToplevel(true)
  end
  dialog:EnableMouse(true)
  dialog:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 120)
  dialog.native = StyledTextInputPopup.nativeChrome == true
  dialog.paintBackground = createBackground(factory, dialog)

  local body = factory.CreateFrame("Frame", nil, dialog)
  body:SetAllPoints(dialog)
  body:SetFrameLevel(dialog:GetFrameLevel() + 2)
  dialog.body = body
  dialog.title = createText(body, Theme.FONTS.icon_label)
  dialog.firstLabel = createText(body, Theme.FONTS.system_text)
  dialog.firstInput = createInput(factory, body)
  dialog.secondLabel = createText(body, Theme.FONTS.system_text)
  dialog.secondInput = createInput(factory, body)
  dialog.hint = createText(body, Theme.FONTS.contact_preview)
  dialog.acceptButton = createButton(factory, body)
  dialog.cancelButton = createButton(factory, body)
  layout(dialog)

  function dialog.refreshAccept()
    local ready = trimmed(dialog.secondInput) ~= ""
    dialog.acceptButton:SetEnabled(ready)
    dialog.acceptButton:SetAlpha(ready and 1 or 0.5)
  end

  function dialog.accept()
    local second = trimmed(dialog.secondInput)
    if second == "" then
      return
    end
    local first = trimmed(dialog.firstInput)
    local onAccept = dialog.onAccept
    dialog:Hide()
    if onAccept then
      onAccept(first, second)
    end
  end

  wireKeys(dialog)
  -- Escape closes it even when neither field has focus.
  if type(_G.UISpecialFrames) == "table" then
    table.insert(_G.UISpecialFrames, TwoFieldDialog.FRAME_NAME)
  end
  dialog:Hide()
  return dialog
end

-- Theme colours are read on every Show, so a theme change since the last
-- one is picked up.
local function paint(dialog)
  if dialog.paintBackground then
    dialog.paintBackground()
  end
  local titleColor = dialog.native and NATIVE_TITLE_COLOR or Theme.COLORS.text_primary
  local textColor = dialog.native and NATIVE_TEXT_COLOR or Theme.COLORS.text_primary
  local hintColor = dialog.native and NATIVE_HINT_COLOR or Theme.COLORS.text_secondary
  UIHelpers.setTextColor(dialog.title, titleColor)
  UIHelpers.setTextColor(dialog.firstLabel, textColor)
  UIHelpers.setTextColor(dialog.secondLabel, textColor)
  UIHelpers.setTextColor(dialog.hint, hintColor)
  for _, box in ipairs({ dialog.firstInput, dialog.secondInput }) do
    if box.background and box.background.setColor then
      box.background.setColor(Theme.COLORS.bg_input)
    end
    UIHelpers.setTextColor(box, Theme.COLORS.text_primary)
  end
end

local function fill(box, value, maxLetters)
  if maxLetters and box.SetMaxLetters then
    box:SetMaxLetters(maxLetters)
  end
  box:SetText(value or "")
end

-- spec: title, accept (localized labels), firstLabel / secondLabel, hint,
-- firstValue / secondValue, firstMaxLetters / secondMaxLetters, and
-- onAccept(firstText, secondText) with both trimmed. Returns the dialog.
function TwoFieldDialog.Show(factory, spec)
  local dialog = dialogs[factory]
  if dialog == nil then
    dialog = build(factory)
    dialogs[factory] = dialog
  end
  dialog.onAccept = spec.onAccept
  dialog.title:SetText(spec.title or "")
  dialog.firstLabel:SetText(spec.firstLabel or "")
  dialog.secondLabel:SetText(spec.secondLabel or "")
  dialog.hint:SetText(spec.hint or "")
  dialog.acceptButton.label:SetText(spec.accept or "")
  dialog.cancelButton.label:SetText(Localization.Text("Cancel"))
  fill(dialog.firstInput, spec.firstValue, spec.firstMaxLetters)
  fill(dialog.secondInput, spec.secondValue, spec.secondMaxLetters)
  local hintHeight = spec.hint and (dialog.hint:GetStringHeight() or 0) + LABEL_GAP or 0
  local fieldsHeight = (LABEL_HEIGHT + LABEL_GAP + INPUT_HEIGHT) * 2 + FIELD_GAP
  dialog:SetSize(WIDTH, PADDING * 3 + TITLE_SPACE + fieldsHeight + hintHeight + Theme.LAYOUT.OPTION_BUTTON_HEIGHT)
  paint(dialog)
  dialog.refreshAccept()
  dialog:Show()
  dialog.firstInput:SetFocus()
  return dialog
end

ns.TwoFieldDialog = TwoFieldDialog
return TwoFieldDialog
