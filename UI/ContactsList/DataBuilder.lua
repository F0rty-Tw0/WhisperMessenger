local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DataBuilder = {}

local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")

local function compareItems(left, right)
  local leftPinned = left.pinned and true or false
  local rightPinned = right.pinned and true or false
  if leftPinned ~= rightPinned then
    return leftPinned
  end

  -- sortOrder only applies within the pinned group
  if leftPinned and rightPinned then
    local leftOrder = left.sortOrder or 0
    local rightOrder = right.sortOrder or 0
    if leftOrder ~= 0 or rightOrder ~= 0 then
      if leftOrder ~= rightOrder then
        if leftOrder == 0 then
          return false
        end
        if rightOrder == 0 then
          return true
        end
        return leftOrder < rightOrder
      end
    end
  end

  if left.lastActivityAt ~= right.lastActivityAt then
    return left.lastActivityAt > right.lastActivityAt
  end

  return (left.displayName or "") < (right.displayName or "")
end


function DataBuilder.BuildItems(conversations)
  local items = {}

  for conversationKey, conversation in pairs(conversations or {}) do
    table.insert(items, ConversationSnapshot.Build(conversationKey, conversation))
  end

  table.sort(items, compareItems)
  return items
end

function DataBuilder.BuildItemsForProfile(savedState, localProfileId)
  local items = {}
  local profilePrefix = localProfileId .. "::"
  local bnetPrefix = "bnet::"
  local wowPrefix = "wow::"

  for conversationKey, conversation in pairs(savedState.conversations or {}) do
    if
      string.find(conversationKey, profilePrefix, 1, true) == 1
      or string.find(conversationKey, bnetPrefix, 1, true) == 1
      or string.find(conversationKey, wowPrefix, 1, true) == 1
    then
      table.insert(items, ConversationSnapshot.Build(conversationKey, conversation))
    end
  end

  table.sort(items, compareItems)
  return items
end

ns.ContactsListDataBuilder = DataBuilder
return DataBuilder
