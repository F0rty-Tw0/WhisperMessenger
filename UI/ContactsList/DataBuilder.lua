local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DataBuilder = {}

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

local function buildItem(conversationKey, conversation)
  return {
    conversationKey = conversationKey,
    displayName = conversation.displayName or conversation.contactDisplayName or conversationKey,
    lastPreview = conversation.lastPreview or "",
    unreadCount = conversation.unreadCount or 0,
    lastActivityAt = conversation.lastActivityAt or 0,
    channel = conversation.channel or "WOW",
    guid = conversation.guid,
    bnetAccountID = conversation.bnetAccountID,
    battleTag = conversation.battleTag,
    gameAccountName = conversation.gameAccountName,
    className = conversation.className,
    classTag = conversation.classTag,
    raceName = conversation.raceName,
    raceTag = conversation.raceTag,
    factionName = conversation.factionName,
    pinned = conversation.pinned or false,
    sortOrder = conversation.sortOrder or 0,
  }
end

function DataBuilder.BuildItems(conversations)
  local items = {}

  for conversationKey, conversation in pairs(conversations or {}) do
    table.insert(items, buildItem(conversationKey, conversation))
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
      table.insert(items, buildItem(conversationKey, conversation))
    end
  end

  table.sort(items, compareItems)
  return items
end

ns.ContactsListDataBuilder = DataBuilder
return DataBuilder
