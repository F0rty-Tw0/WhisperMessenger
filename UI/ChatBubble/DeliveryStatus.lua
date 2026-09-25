local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local OutgoingDelivery = ns.OutgoingDelivery or require("WhisperMessenger.Model.OutgoingDelivery")
local DeliveryMenu = ns.ChatBubbleDeliveryMenu or require("WhisperMessenger.UI.ChatBubble.DeliveryMenu")

-- "(Not sent)" / "(Queued)" in an outgoing message's sender header, left of
-- the timestamp. Clicking it opens DeliveryMenu (Send now / Retry / Discard).
-- The button is cached on the pooled header frame and re-shown per render.
local DeliveryStatus = {}

local STATUS_KEYS = { queued = "Queued", notSent = "Not sent" }
local BUTTON_HEIGHT = 16
local BUTTON_TEXT_PAD = 4

local function statusColor(status)
  if status == "notSent" then
    return Theme.COLORS.danger_text or Theme.COLORS.text_secondary
  end
  return Theme.COLORS.text_secondary
end

local function paint(button, hovered)
  UIHelpers.setTextColor(button._wmLabel, hovered and Theme.COLORS.text_primary or statusColor(button._wmStatus))
end

local function onClick(button)
  if type(button._wmOnAction) ~= "function" then
    return
  end
  local actions = OutgoingDelivery.Actions(button._wmMessage, button._wmChatLocked == true)
  DeliveryMenu.Open(button._wmFactory, button, button._wmMessage, actions, button._wmOnAction)
end

local function ensureButton(frame, factory)
  local button = frame._wmDeliveryButton
  if button == nil then
    button = factory.CreateFrame("Button", nil, frame)
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button._wmLabel = label
    button:SetScript("OnEnter", function(self)
      paint(self, self._wmOnAction ~= nil)
    end)
    button:SetScript("OnLeave", function(self)
      paint(self, false)
    end)
    button:SetScript("OnClick", onClick)
    frame._wmDeliveryButton = button
  end
  return button
end

function DeliveryStatus.Hide(frame)
  local button = frame._wmDeliveryButton
  if button then
    button:Hide()
    button._wmMessage = nil
    button._wmOnAction = nil
    button._wmFactory = nil
  end
end

-- Places the status left of `anchor`. Returns true when a status shows.
-- options: chatLocked, onMessageAction(message, action), persistentFactory
function DeliveryStatus.ApplyHeader(frame, message, anchor, options)
  local status = OutgoingDelivery.Status(message)
  local factory = options and options.persistentFactory
  if status == nil or factory == nil then
    DeliveryStatus.Hide(frame)
    return false
  end
  local button = ensureButton(frame, factory)
  button._wmStatus = status
  button._wmMessage = message
  button._wmChatLocked = options.chatLocked
  button._wmFactory = factory
  button._wmOnAction = type(options.onMessageAction) == "function" and options.onMessageAction or nil

  local label = button._wmLabel
  UIHelpers.setFontObject(label, Theme.FONTS.message_time)
  label:SetText("(" .. Localization.Text(STATUS_KEYS[status]) .. ")")
  label:Show()
  paint(button, false)
  button:SetSize(label:GetStringWidth() + BUTTON_TEXT_PAD, BUTTON_HEIGHT)
  button:ClearAllPoints()
  button:SetPoint("RIGHT", anchor, "LEFT", -Theme.LAYOUT.MESSAGE_TIMESTAMP_GAP, 0)
  button:Show()
  return true
end

ns.ChatBubbleDeliveryStatus = DeliveryStatus
return DeliveryStatus
