local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

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

-- options: { onMarkUnread, onUpdatePrefs } (the pane's menu callbacks).
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
    if button ~= "RightButton" then
      return
    end
    local contact = view and view._selectedContact
    if contact == nil then
      return
    end
    local cm = contextMenu or ContactsContextMenu
    if type(cm) ~= "table" or type(cm.Open) ~= "function" then
      return
    end
    cm.Open(contact, headerFrame, options.onMarkUnread, options.onUpdatePrefs)
  end)

  for _, eventName in ipairs(FORWARDED_EVENTS) do
    headerFrame:SetScript(eventName, forward(headerFrame, eventName))
  end
end

ns.ConversationPaneHeaderMenu = HeaderMenu
return HeaderMenu
