local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationSnapshot = {}

function ConversationSnapshot.Build(conversationKey, conversation)
  conversation = conversation or {}

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

ns.ConversationSnapshot = ConversationSnapshot
return ConversationSnapshot
