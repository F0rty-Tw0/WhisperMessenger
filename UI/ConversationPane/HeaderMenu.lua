local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ContactsContextMenu = ns.ContactsListContextMenu or require("WhisperMessenger.UI.ContactsList.ContextMenu")

-- Right-click on the conversation header opens that conversation's menu: the
-- player menu for a whisper (same as right-clicking the sender's name), the
-- group menu for a group chat.
local HeaderMenu = {}

-- The header took no mouse input before this, so clicks and drags on it fell
-- through to the messenger window (raise on click, drag to move). Taking the
-- mouse swallows them, so these window scripts are forwarded.
local FORWARDED_EVENTS = { "OnMouseDown", "OnDragStart", "OnDragStop" }

-- Looked up when the event fires: the window binds its scripts after the
-- pane is built.
local function findScriptedAncestor(frame, eventName)
  local ancestor = type(frame.GetParent) == "function" and frame:GetParent() or nil
  while ancestor ~= nil do
    local script = type(ancestor.GetScript) == "function" and ancestor:GetScript(eventName) or nil
    if script ~= nil then
      return ancestor, script
    end
    ancestor = type(ancestor.GetParent) == "function" and ancestor:GetParent() or nil
  end

  return nil, nil
end

local function forward(headerFrame, eventName)
  return function(_self, ...)
    local ancestor, script = findScriptedAncestor(headerFrame, eventName)
    if script ~= nil then
      script(ancestor, ...)
    end
  end
end

local function isMouseOver(region)
  if region == nil or type(region.IsMouseOver) ~= "function" then
    return false
  end
  local ok, value = pcall(region.IsMouseOver, region)
  return ok and value == true
end

-- Shift + left-click on the name text of a whisper chat sends a /who. A drag
-- that moves the window also ends in OnMouseUp, so a drag cancels the click.
local function shouldWho(view, contact, button, options)
  if button ~= "LeftButton" or type(options.whoPlayer) ~= "function" then
    return false
  end
  if contact == nil or contact.channel ~= "WOW" or view._wmHeaderDragged then
    return false
  end

  return UIHelpers.isShiftDown() and isMouseOver(view.headerName)
end

-- Forward the window scripts the header swallows; a drag start/stop is also
-- recorded on the view so a drag cancels the shift-click.
local function bindForwarders(headerFrame, view)
  local dragFlags = { OnMouseDown = false, OnDragStart = true }
  for _, eventName in ipairs(FORWARDED_EVENTS) do
    local forwarder = forward(headerFrame, eventName)
    local dragged = dragFlags[eventName]
    headerFrame:SetScript(eventName, function(self, ...)
      if view and dragged ~= nil then
        view._wmHeaderDragged = dragged
      end
      forwarder(self, ...)
    end)
  end
end

-- options: { onMarkUnread, onUpdatePrefs, whoPlayer } (the pane's callbacks).
-- contextMenu (optional): stands in for the contacts list menu in tests.
function HeaderMenu.Bind(headerFrame, view, options, contextMenu)
  if type(headerFrame) ~= "table" or type(headerFrame.SetScript) ~= "function" then
    return
  end
  options = options or {}

  if headerFrame.EnableMouse then
    headerFrame:EnableMouse(true)
  end
  if headerFrame.RegisterForDrag then
    headerFrame:RegisterForDrag("LeftButton")
  end

  headerFrame:SetScript("OnMouseUp", function(_self, button)
    local contact = view and view._selectedContact
    if view and shouldWho(view, contact, button, options) then
      options.whoPlayer(contact.displayName)

      return
    end
    if button ~= "RightButton" then
      return
    end
    if contact == nil then
      return
    end
    local cm = contextMenu or ContactsContextMenu
    if type(cm) ~= "table" or type(cm.Open) ~= "function" then
      return
    end
    cm.Open(contact, headerFrame, options.onMarkUnread, options.onUpdatePrefs)
  end)

  bindForwarders(headerFrame, view)
end

ns.ConversationPaneHeaderMenu = HeaderMenu
return HeaderMenu
