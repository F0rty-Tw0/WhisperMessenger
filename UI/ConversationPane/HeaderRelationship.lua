local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local RelationshipMark = ns.RelationshipMark or require("WhisperMessenger.UI.Shared.RelationshipMark")
local HeaderFit = ns.ConversationPaneHeaderFit or require("WhisperMessenger.UI.ConversationPane.HeaderFit")

-- The relationship mark after the contact's name in the chat header. The
-- faction icon follows the mark when it shows, else the name.
local HeaderRelationship = {}

-- Adds view.headerRelationship (the mark), view.headerRelationshipIcon and
-- view.headerRelationshipHover.
function HeaderRelationship.Create(view, headerFrame, headerName)
  local mark = RelationshipMark.Create(headerFrame, Theme.LAYOUT.HEADER_RELATIONSHIP_SIZE)
  mark.icon:SetPoint("LEFT", headerName, "RIGHT", HeaderFit.NAME_ROW_GAP, 0)
  view.headerRelationship = mark
  view.headerRelationshipIcon = mark.icon
  view.headerRelationshipHover = mark.hover
end

-- No mark on group conversations.
function HeaderRelationship.Refresh(view, selectedContact, isGroup)
  local mark = view.headerRelationship
  if mark == nil then
    return
  end
  local rel = selectedContact ~= nil and not isGroup and selectedContact.relationship or nil
  local shown = RelationshipMark.Bind(mark, rel)
  local faction = view.headerFactionIcon
  if faction and type(faction.ClearAllPoints) == "function" then
    faction:ClearAllPoints()
    faction:SetPoint("LEFT", shown and mark.icon or view.headerName, "RIGHT", HeaderFit.NAME_ROW_GAP, 0)
  end
end

ns.ConversationPaneHeaderRelationship = HeaderRelationship
return HeaderRelationship
