local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Composer = {}
local registeredLinkHooks = false
local linkedInputs = {}

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")

local UIHelpers = loadModule("WhisperMessenger.UI.Helpers", "UIHelpers")
local sizeValue = UIHelpers.sizeValue

local function canInsertLink(input)
  if input == nil or type(input.Insert) ~= "function" then
    return false
  end

  if type(input.HasFocus) == "function" and not input:HasFocus() then
    return false
  end

  if type(input.IsShown) == "function" and not input:IsShown() then
    return false
  end

  return true
end

local function tryInsertLink(link)
  if link == nil then
    return false
  end

  for _, input in ipairs(linkedInputs) do
    if canInsertLink(input) then
      input:Insert(link)
      return true
    end
  end

  return false
end

local function registerLinkHooks()
  if registeredLinkHooks or type(_G.hooksecurefunc) ~= "function" then
    return
  end

  _G.hooksecurefunc("HandleModifiedItemClick", function(link)
    tryInsertLink(link)
  end)
  _G.hooksecurefunc("SetItemRef", function(link, text)
    tryInsertLink(text or link)
  end)

  registeredLinkHooks = true
end

function Composer.Create(factory, parent, selectedContact, onSend, onEscape)
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  pane:SetAllPoints(parent)

  -- Pane background
  local paneBg = pane:CreateTexture(nil, "BACKGROUND")
  paneBg:SetAllPoints(pane)
  local bc = Theme.COLORS.bg_composer
  if paneBg.SetColorTexture then
    paneBg:SetColorTexture(bc[1], bc[2], bc[3], bc[4])
  end

  -- Input background texture (sits behind the EditBox)
  local inputBg = pane:CreateTexture(nil, "BACKGROUND")
  local inputW = parentWidth - 24
  local inputH = Theme.LAYOUT.COMPOSER_INPUT_HEIGHT
  local inputX, inputY = 12, 8
  inputBg:SetSize(inputW, inputH)
  inputBg:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  local ic = Theme.COLORS.bg_input
  if inputBg.SetColorTexture then
    inputBg:SetColorTexture(ic[1], ic[2], ic[3], ic[4])
  end

  -- Send button
  local buttonW = 72
  local buttonH = inputH
  local button = factory.CreateFrame("Button", nil, pane)
  button:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -inputX, inputY)
  button:SetSize(buttonW, buttonH)
  local buttonLabel = button:CreateFontString(nil, "OVERLAY", Theme.FONTS.composer_input)
  buttonLabel:SetAllPoints(button)
  buttonLabel:SetText("Send")

  -- Plain EditBox (no template)
  local inputW2 = inputW - buttonW - 8
  local input = factory.CreateFrame("EditBox", nil, pane)
  input:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  input:SetSize(inputW2, inputH)
  input:SetText("")

  local fontObj = _G.ChatFontNormal or "ChatFontNormal"
  if input.SetFontObject then
    input:SetFontObject(fontObj)
  end
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
  local tc = Theme.COLORS.text_secondary
  if placeholder.SetTextColor then
    placeholder:SetTextColor(tc[1], tc[2], tc[3], tc[4])
  end
  placeholder:Show()

  table.insert(linkedInputs, 1, input)
  registerLinkHooks()

  local sendDisabled = selectedContact == nil
  button.disabled = sendDisabled

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
    sendButton = button,
    setEnabled = function(enabled)
      sendDisabled = not enabled
      button.disabled = not enabled
    end,
  }
end

ns.Composer = Composer

return Composer
