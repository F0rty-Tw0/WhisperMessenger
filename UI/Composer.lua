local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Composer = {}

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

function Composer.Create(factory, parent, selectedContact, onSend)
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  pane:SetAllPoints(parent)

  local input = factory.CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
  input:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 16, 16)
  input:SetSize(parentWidth - 120, 24)
  input:SetText("")

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

  return {
    frame = pane,
    input = input,
    sendButton = sendButton,
  }
end

ns.Composer = Composer

return Composer
