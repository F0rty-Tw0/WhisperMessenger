local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Composer = {}
local registeredLinkHooks = false
local linkedInputs = {}

local function sizeValue(target, getterName, fieldName, fallback)
  if target and type(target[getterName]) == "function" then
    local value = target[getterName](target)
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  if target and type(target[fieldName]) == "number" then
    return target[fieldName]
  end

  return fallback
end

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

  local input = factory.CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
  input:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 16, 16)
  input:SetSize(parentWidth - 120, 24)
  input:SetText("")
  if input.SetAutoFocus then
    input:SetAutoFocus(false)
  end
  if input.SetAltArrowKeyMode then
    input:SetAltArrowKeyMode(false)
  end
  if input.SetHyperlinksEnabled then
    input:SetHyperlinksEnabled(true)
  end

  table.insert(linkedInputs, 1, input)
  registerLinkHooks()

  local sendButton = factory.CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
  sendButton:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -16, 16)
  sendButton:SetSize(88, 24)
  sendButton:SetText("Send")
  sendButton.disabled = selectedContact == nil

  local function submitMessage()
    if sendButton.disabled then
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

  sendButton:SetScript("OnClick", submitMessage)
  input:SetScript("OnEnterPressed", function()
    submitMessage()
  end)
  input:SetScript("OnEscapePressed", function()
    if input.ClearFocus then
      input:ClearFocus()
    end
    if onEscape then
      onEscape()
    end
  end)

  return {
    frame = pane,
    input = input,
    sendButton = sendButton,
  }
end

ns.Composer = Composer

return Composer
