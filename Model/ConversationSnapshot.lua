local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationSnapshot = {}

local function appendSearchPart(parts, value)
  if type(value) ~= "string" or value == "" then
    return
  end

  parts[#parts + 1] = string.lower(value)
end

local function buildSearchText(conversationKey, conversation, displayName, lastPreview)
  local parts = {}

  appendSearchPart(parts, displayName)
  appendSearchPart(parts, conversation.contactDisplayName)
  appendSearchPart(parts, conversationKey)
  appendSearchPart(parts, conversation.battleTag)
  appendSearchPart(parts, conversation.gameAccountName)
  appendSearchPart(parts, conversation.className)
  appendSearchPart(parts, conversation.raceName)
  appendSearchPart(parts, conversation.factionName)
  appendSearchPart(parts, lastPreview)

  for _, message in ipairs(conversation.messages or {}) do
    if type(message) == "table" then
      appendSearchPart(parts, message.text)
      appendSearchPart(parts, message.playerName)
    end
  end

  return table.concat(parts, "\n")
end

function ConversationSnapshot.Build(conversationKey, conversation)
  conversation = conversation or {}

  local displayName = conversation.displayName or conversation.contactDisplayName or conversationKey
  local lastPreview = conversation.lastPreview or ""

  return {
    conversationKey = conversationKey,
    displayName = displayName,
    title = conversation.title,
    lastPreview = lastPreview,
    searchText = buildSearchText(conversationKey, conversation, displayName, lastPreview),
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
    guildName = conversation.guildName,
  }
end

ns.ConversationSnapshot = ConversationSnapshot
return ConversationSnapshot
