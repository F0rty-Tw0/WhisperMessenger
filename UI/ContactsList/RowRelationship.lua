local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local RelationshipMark = ns.RelationshipMark or require("WhisperMessenger.UI.Shared.RelationshipMark")

-- The contact row's relationship mark: sits one gap after the name text and
-- pushes the faction icon one more gap to the right. Group rows never show it.
local RowRelationship = {}

-- Also the name-to-faction gap: RowElements budgets the name with it.
local GAP = 4
RowRelationship.GAP = GAP

local function markSize()
  return Theme.LAYOUT.CONTACT_RELATIONSHIP_SIZE
end

local function isShown(row)
  local mark = row.relationshipMark
  return mark ~= nil and mark.icon:IsShown() == true
end

-- Must run right after the name label is refit: it shrinks that fresh width,
-- so a later bind without a tie gets the full width back.
function RowRelationship.Bind(row, item, isGroup)
  local rel = (not isGroup) and item and item.relationship or nil
  if rel == nil and row.relationshipMark == nil then
    return false
  end
  if row.relationshipMark == nil then
    local mark = RelationshipMark.Create(row, markSize())
    row.relationshipMark = mark
    row.relationshipIcon = mark.icon
    row.relationshipHover = mark.hover
  end
  local shown = RelationshipMark.Bind(row.relationshipMark, rel)
  if shown and row.title and row.title.GetWidth then
    row.title:SetWidth(math.max(0, row.title:GetWidth() - markSize() - GAP))
  end
  return shown
end

-- Places the mark after the fitted name text; returns the faction icon's x
-- offset from the name's left edge.
function RowRelationship.Anchor(row, textW)
  if row.title == nil or not isShown(row) then
    return textW + GAP
  end
  local icon = row.relationshipMark.icon
  icon:ClearAllPoints()
  icon:SetPoint("LEFT", row.title, "LEFT", textW + GAP, 0)
  return textW + GAP + markSize() + GAP
end

ns.ContactsListRowRelationship = RowRelationship
return RowRelationship
