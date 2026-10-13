local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Right-click or shift + left-click on a sender label or avatar hands the
-- click to an opener. Without one, right-click opens the player menu.
local PlayerMenuClick = {}

local function defaultOpenPlayerMenu(message, anchor, button)
  if button ~= nil and button ~= "RightButton" then
    return false
  end
  local PM = ns.ChatBubblePlayerMenu
  if type(PM) ~= "table" or type(PM.Open) ~= "function" then
    return false
  end
  return PM.Open(message, anchor)
end

local function isShiftLeftClick(button)
  return button == "LeftButton" and UIHelpers.isShiftDown()
end

local function onMouseUp(self, button)
  if button ~= "RightButton" and not isShiftLeftClick(button) then
    return
  end
  local opener = self._wmPlayerMenuOpener
  if type(opener) == "function" then
    opener(self._wmPlayerMenuMessage, self, button)
  end
end

function PlayerMenuClick.Attach(frame, message, opener)
  if type(frame.EnableMouse) ~= "function" or type(frame.SetScript) ~= "function" then
    return
  end
  frame._wmPlayerMenuMessage = message
  frame._wmPlayerMenuOpener = opener or defaultOpenPlayerMenu
  frame:EnableMouse(true)
  frame:SetScript("OnMouseUp", onMouseUp)
end

ns.ChatBubblePlayerMenuClick = PlayerMenuClick

return PlayerMenuClick
