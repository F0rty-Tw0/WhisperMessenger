local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")
local GroupChats = ns.GroupChats or require("WhisperMessenger.Model.GroupChats")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local Mention = ns.GroupChatIngestMention or require("WhisperMessenger.Core.Ingest.GroupChatIngest.Mention")

-- Puts a group chat's lines into the conversation store. The group record
-- (Model/GroupChats) is the source of truth; the conversation is its
-- history and is re-created from the record whenever it is missing.
local ConversationWriter = {}

local sequence = 0
local function nextMessageId(prefix, sentAt)
  sequence = sequence + 1
  return prefix .. tostring(sentAt) .. "-" .. tostring(sequence)
end

local function isOpen(runtime, conversationKey)
  if type(runtime.isConversationOpen) == "function" then
    return runtime.isConversationOpen(conversationKey) == true
  end
  return runtime.activeConversationKey == conversationKey
end

-- Creates the conversation when missing and copies the group's name,
-- members and state onto it. Returns the conversation and its key.
function ConversationWriter.Ensure(runtime, group, now)
  local conversationKey = GroupChats.ConversationKey(group.id)
  local conversation = Store.EnsureConversation(runtime.store, conversationKey, {
    channel = ChannelType.WM_GROUP,
    displayName = group.name,
    lastActivityAt = now or group.createdAt or 0,
  })
  conversation.channel = ChannelType.WM_GROUP
  conversation.conversationKey = conversationKey
  conversation.groupChatId = group.id
  conversation.title = group.name
  conversation.memberSummary = GroupChats.MemberSummary(group, LocalPlayer.NormalizedRealm())
  conversation.leftGroup = group.left == true or nil
  return conversation, conversationKey
end

function ConversationWriter.AppendIncoming(runtime, group, sender, text, now)
  local _, conversationKey = ConversationWriter.Ensure(runtime, group, now)
  local message = {
    id = nextMessageId("wmg-in-", now),
    direction = "in",
    kind = "user",
    text = text,
    sentAt = now,
    playerName = sender,
    channel = ChannelType.WM_GROUP,
  }
  local playerName = LocalPlayer.Name()
  if playerName and Mention.FindWord(text, playerName, 1) ~= nil then
    message.mention = true
  end
  Store.AppendIncoming(runtime.store, conversationKey, message, isOpen(runtime, conversationKey))
  return runtime.store.conversations[conversationKey], message
end

function ConversationWriter.AppendOutgoing(runtime, group, text, now)
  local _, conversationKey = ConversationWriter.Ensure(runtime, group, now)
  local playerName = LocalPlayer.Name()
  local realm = LocalPlayer.NormalizedRealm()
  local message = {
    id = nextMessageId("wmg-out-", now),
    direction = "out",
    kind = "user",
    text = text,
    sentAt = now,
    playerName = playerName and realm and (playerName .. "-" .. realm) or playerName,
    senderName = playerName,
    senderClassTag = LocalPlayer.ClassTag(),
    channel = ChannelType.WM_GROUP,
  }
  Store.AppendOutgoing(runtime.store, conversationKey, message)
  return runtime.store.conversations[conversationKey], message
end

-- A grey centered line ("Anna left the group chat."); never unread.
function ConversationWriter.AppendNotice(runtime, group, text, now)
  local _, conversationKey = ConversationWriter.Ensure(runtime, group, now)
  Store.AppendIncoming(runtime.store, conversationKey, {
    id = nextMessageId("wmg-sys-", now),
    kind = "system",
    direction = "in",
    text = text,
    sentAt = now,
    channel = ChannelType.WM_GROUP,
  }, true)
  return runtime.store.conversations[conversationKey]
end

ns.GroupChatConversationWriter = ConversationWriter
return ConversationWriter
