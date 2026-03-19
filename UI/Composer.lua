local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Composer = {}

function Composer.Create(factory, parent, selectedContact, onSend)
  local pane = factory.CreateFrame("Frame", nil, parent)
  pane:SetAllPoints(parent)

  local input = factory.CreateFrame("EditBox", nil, pane)
  input:SetText("")

  local sendButton = factory.CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
  sendButton:SetText("Send")
  sendButton.disabled = selectedContact == nil

  sendButton:SetScript("OnClick", function()
    if sendButton.disabled then
      return
    end

    local text = input.text
    if text == nil or text == "" then
      return
    end

    onSend({
      conversationKey = selectedContact.conversationKey,
      target = selectedContact.displayName,
      text = text,
    })

    input:SetText("")
  end)

  return {
    frame = pane,
    input = input,
    sendButton = sendButton,
  }
end

ns.Composer = Composer

return Composer
