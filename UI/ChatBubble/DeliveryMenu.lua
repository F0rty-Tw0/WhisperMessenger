local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")

-- Small popup under a "(Not sent)" / "(Queued)" label: one row per action
-- (Send now / Retry / Discard). Looks and closes like the reaction picker.
local DeliveryMenu = {}

local MENU_FRAME_NAME = "WhisperMessengerDeliveryMenu"
local ACTION_KEYS = { send_now = "Send now", discard = "Discard", retry = "Retry" }
local MAX_ACTIONS = 2
local PAD = 4
local ROW_HEIGHT = PickerStyles.ROW_HEIGHT
local MIN_WIDTH = 90
local LABEL_PAD = 24

local menuFrame

local function onActionClick(button)
  local message, onAction, action = menuFrame._message, menuFrame._onAction, button._action
  DeliveryMenu.Close()
  if type(onAction) == "function" then
    onAction(message, action)
  end
end

local function createMenu(factory)
  local parent = _G.UIParent
  if type(factory) ~= "table" or type(factory.CreateFrame) ~= "function" or parent == nil then
    return nil
  end
  local frame = PickerPopup.CreatePanel(factory, parent, MENU_FRAME_NAME, "FULLSCREEN_DIALOG")

  frame._buttons = {}
  for index = 1, MAX_ACTIONS do
    local button, label = PickerPopup.CreateTextButton(factory, frame, "Discard", onActionClick)
    button._label = label
    frame._buttons[index] = button
  end

  frame:SetScript("OnEvent", function(self, event)
    PickerPopup.HandleEvent(self, event, DeliveryMenu.Close)
  end)
  frame:SetScript("OnHide", function(self)
    PickerPopup.Disarm(self)
    self._message = nil
    self._onAction = nil
  end)
  rawset(_G, MENU_FRAME_NAME, frame)
  PickerPopup.RegisterEscape(MENU_FRAME_NAME)
  return frame
end

-- Stacks one button per action and sizes the frame to the widest label.
local function layoutButtons(frame, actions)
  local width = MIN_WIDTH
  for index, button in ipairs(frame._buttons) do
    local action = actions[index]
    if action then
      button._action = action
      button._label:SetText(Localization.Text(ACTION_KEYS[action]))
      width = math.max(width, button._label:GetStringWidth() + LABEL_PAD)
      button:Show()
    else
      button._action = nil
      button:Hide()
    end
  end
  for index = 1, #actions do
    local button = frame._buttons[index]
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD - (index - 1) * ROW_HEIGHT)
    button:SetSize(width, ROW_HEIGHT)
  end
  frame:SetSize(width + PAD * 2, #actions * ROW_HEIGHT + PAD * 2)
end

-- actions: display-ordered keys from OutgoingDelivery.Actions.
-- onAction(message, action) runs after the menu closes.
function DeliveryMenu.Open(factory, anchorFrame, message, actions, onAction)
  if type(actions) ~= "table" or #actions == 0 or #actions > MAX_ACTIONS then
    return false
  end
  menuFrame = menuFrame or createMenu(factory)
  if menuFrame == nil then
    return false
  end
  PickerStyles.ApplyPanelTheme(menuFrame, menuFrame._border)
  menuFrame._message = message
  menuFrame._onAction = onAction
  layoutButtons(menuFrame, actions)
  menuFrame:ClearAllPoints()
  menuFrame:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -2)
  PickerPopup.ArmDismiss(menuFrame)
  menuFrame:Show()
  return true
end

function DeliveryMenu.Close()
  if menuFrame then
    menuFrame:Hide()
  end
end

function DeliveryMenu.GetFrame()
  return menuFrame
end

ns.ChatBubbleDeliveryMenu = DeliveryMenu
return DeliveryMenu
