local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture
local setTextColor = UIHelpers.setTextColor

local LinkHooks = ns.ComposerLinkHooks or require("WhisperMessenger.UI.Composer.LinkHooks")

local Composer = {}

function Composer.Create(factory, parent, selectedContact, onSend, onEscape)
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  pane:SetAllPoints(parent)

  -- Pane background
  local paneBg = pane:CreateTexture(nil, "BACKGROUND")
  paneBg:SetAllPoints(pane)
  applyColorTexture(paneBg, Theme.COLORS.bg_composer)

  -- Input background texture (sits behind the EditBox)
  local inputBg = pane:CreateTexture(nil, "BACKGROUND")
  local buttonW = 44
  local buttonH = 30
  local buttonGap = 8
  local inputW = parentWidth - 24 - buttonW - buttonGap
  local inputH = Theme.LAYOUT.COMPOSER_INPUT_HEIGHT
  local inputX, inputY = 12, 8
  inputBg:SetSize(inputW, inputH)
  inputBg:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  applyColorTexture(inputBg, Theme.COLORS.bg_input)

  -- Send button (compact rounded pill)
  local createRoundedBackground = UIHelpers.createRoundedBackground
  local button = factory.CreateFrame("Button", nil, pane)
  button:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -inputX, inputY + (inputH - buttonH) / 2)
  button:SetSize(buttonW, buttonH)

  local sendBg = createRoundedBackground(button, 8)
  local applySendColor = sendBg.setColor

  local buttonLabel = button:CreateFontString(nil, "OVERLAY", Theme.FONTS.composer_input)
  buttonLabel:SetPoint("CENTER", button, "CENTER", 0, 0)
  buttonLabel:SetText("Send")

  -- Plain EditBox (no template)
  local input = factory.CreateFrame("EditBox", nil, pane)
  input:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  input:SetSize(inputW, inputH)
  input:SetText("")

  UIHelpers.setFontObject(input, Theme.FONTS.composer_input)
  if input.SetTextInsets then
    input:SetTextInsets(8, 8, 4, 4)
  end
  if input.SetAutoFocus then
    input:SetAutoFocus(false)
  end
  if input.SetAltArrowKeyMode then
    input:SetAltArrowKeyMode(false)
  end
  if input.SetHyperlinksEnabled then
    input:SetHyperlinksEnabled(true)
  end

  -- Placeholder text
  local placeholder = pane:CreateFontString(nil, "OVERLAY", Theme.FONTS.composer_input)
  placeholder:SetPoint("LEFT", input, "LEFT", 8, 0)
  placeholder:SetText("Type a message and press Enter")
  setTextColor(placeholder, Theme.COLORS.text_secondary)
  placeholder:Show()

  LinkHooks.RegisterInput(input)

  local sendDisabled = selectedContact == nil
  button.disabled = sendDisabled

  local sendBgColor = sendDisabled and Theme.COLORS.send_button_disabled or Theme.COLORS.send_button
  applySendColor(sendBgColor)

  button:SetScript("OnEnter", function()
    if not sendDisabled then
      applySendColor(Theme.COLORS.send_button_hover)
    end
  end)
  button:SetScript("OnLeave", function()
    if sendDisabled then
      applySendColor(Theme.COLORS.send_button_disabled)
    else
      applySendColor(Theme.COLORS.send_button)
    end
  end)

  local function submitMessage()
    if sendDisabled then
      return
    end

    local text = input.GetText and input:GetText() or input.text
    if text == nil or text == "" then
      return
    end

    onSend({
      conversationKey = selectedContact.conversationKey,
      target = selectedContact.displayName,
      displayName = selectedContact.displayName,
      channel = selectedContact.channel,
      bnetAccountID = selectedContact.bnetAccountID,
      guid = selectedContact.guid,
      gameAccountName = selectedContact.gameAccountName,
      text = text,
    })

    input:SetText("")
  end

  input:SetScript("OnTextChanged", function()
    local text = input.GetText and input:GetText() or input.text or ""
    if text == "" then
      placeholder:Show()
    else
      placeholder:Hide()
    end
  end)

  input:SetScript("OnEnterPressed", function()
    submitMessage()
  end)
  button:SetScript("OnClick", function()
    submitMessage()
  end)
  input:SetScript("OnEscapePressed", function()
    if onEscape then
      onEscape()
      return
    end
    if input.ClearFocus then
      input:ClearFocus()
    end
  end)

  return {
    frame = pane,
    input = input,
    inputBg = inputBg,
    sendButton = button,
    setEnabled = function(enabled)
      sendDisabled = not enabled
      button.disabled = not enabled
      if sendDisabled then
        applySendColor(Theme.COLORS.send_button_disabled)
      else
        applySendColor(Theme.COLORS.send_button)
      end
    end,
    relayout = function(parentW)
      local newInputW = parentW - 24 - buttonW - buttonGap
      input:SetSize(newInputW, inputH)
      inputBg:SetSize(newInputW, inputH)
    end,
  }
end

ns.Composer = Composer
return Composer
