local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local ConversationSnapshot = {}

-- The Channels tab shows while at least one channel is ticked on the Chats
-- settings page; with none ticked, old channel history stays in Groups.
function ConversationSnapshot.HasChannelsTab(settings)
  local enabled = type(settings) == "table" and settings.enabledChannels
  if type(enabled) ~= "table" then
    return false
  end
  for _, isEnabled in pairs(enabled) do
    if isEnabled == true then
      return true
    end
  end
  return false
end

-- settings: account settings; decides whether the conversation counts as a
-- message request (isRequest is only set while the Requests inbox is on)
-- and whether a channel chat sits in the Channels tab (inChannelsTab).
function ConversationSnapshot.Build(conversationKey, conversation, settings)
  conversation = conversation or {}

  local displayName = conversation.displayName or conversation.contactDisplayName or conversationKey
  local lastPreview = conversation.lastPreview or ""

  return {
    conversation = conversation,
    contactDisplayName = conversation.contactDisplayName,
    conversationKey = conversationKey,
    displayName = displayName,
    title = conversation.title,
    lastPreview = lastPreview,
    unreadCount = conversation.unreadCount or 0,
    lastActivityAt = conversation.lastActivityAt or 0,
    leftGroup = conversation.leftGroup,
    channel = conversation.channel or "WOW",
    guid = conversation.guid,
    bnetAccountID = conversation.bnetAccountID,
    conversationID = conversation.conversationID,
    battleTag = conversation.battleTag,
    gameAccountName = conversation.gameAccountName,
    className = conversation.className,
    classTag = conversation.classTag,
    characterLevel = conversation.characterLevel,
    raceName = conversation.raceName,
    raceTag = conversation.raceTag,
    factionName = conversation.factionName,
    pinned = conversation.pinned or false,
    sortOrder = conversation.sortOrder or 0,
    guildName = conversation.guildName,
    draft = conversation.draft,
    muted = conversation.muted,
    nickname = conversation.nickname,
    note = conversation.note,
    notifyOnline = conversation.notifyOnline,
    hasUnreadMention = conversation.hasUnreadMention,
    isRequest = MessageRequests.IsRequest(conversation, settings) or nil,
    inChannelsTab = (conversation.channel == ChannelType.CHANNEL and ConversationSnapshot.HasChannelsTab(settings)) or nil,
  }
end

ns.ConversationSnapshot = ConversationSnapshot
return ConversationSnapshot
