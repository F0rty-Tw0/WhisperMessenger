local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")

local ChannelContextMerger = {}

-- Only one conversation is on screen at a time, so a single memo slot is enough
-- to hand back the same channel message table while the store entry and the
-- resolved sender name are unchanged. The transcript diffs message identity, so
-- a fresh table every refresh would mark that row changed and rebuild bubbles.
local cachedEntry
local cachedPlayerName
local cachedMessage

-- Only 1:1 whisper threads keep a sender's channel post; group threads never do.
local WHISPER_CHANNELS = { WOW = true, BN = true }

local function lookupNameFor(selectedContact)
  if type(selectedContact) ~= "table" then
    return nil
  end
  local name = selectedContact.gameAccountName or selectedContact.displayName
  if type(name) ~= "string" or name == "" then
    return nil
  end
  -- A partner on your own realm arrives without a realm. Add yours so the
  -- store never hands back a same-named player's line from another realm.
  if selectedContact.channel == "WOW" and not string.find(name, "-", 1, true) then
    local realm = LocalPlayer.NormalizedRealm()
    if realm then
      name = name .. "-" .. realm
    end
  end
  return string.lower(name)
end

local function buildChannelMessage(entry, playerName)
  return {
    id = "channel-ctx-" .. tostring(entry.sentAt),
    direction = "in",
    kind = "channel_context",
    text = entry.text,
    sentAt = entry.sentAt,
    playerName = playerName,
    channelLabel = entry.channelLabel,
    zoneChannelID = entry.zoneChannelID,
  }
end

local function insertChronological(messages, channelMsg)
  local insertAt = #messages + 1
  for index, message in ipairs(messages) do
    if (channelMsg.sentAt or 0) < (message.sentAt or 0) then
      insertAt = index
      break
    end
  end
  table.insert(messages, insertAt, channelMsg)
end

-- Keep the sender's latest channel post inside their existing conversation so
-- it outlives the short channel TTL and follows the conversation's own
-- retention and deletion. Only one post per conversation (latest wins); it is
-- context, so unread counts and activity metadata are left untouched.
local function persistIntoConversation(conversation, entry, playerName)
  local messages = conversation.messages
  for index, message in ipairs(messages) do
    if message.kind == "channel_context" then
      if (message.sentAt or 0) > entry.sentAt or (message.sentAt == entry.sentAt and message.text == entry.text) then
        return
      end
      table.remove(messages, index)
      break
    end
  end
  insertChronological(messages, buildChannelMessage(entry, playerName))
end

-- Hide saved channel-context lines without touching the stored conversation.
-- Hands back the same table when there is nothing to hide.
local function withoutChannelContext(messages)
  local hasContext = false
  for _, message in ipairs(messages) do
    if message.kind == "channel_context" then
      hasContext = true
      break
    end
  end
  if not hasContext then
    return messages
  end
  local result = {}
  for _, message in ipairs(messages) do
    if message.kind ~= "channel_context" then
      result[#result + 1] = message
    end
  end
  return result
end

-- Merge a recent channel-context message into the chronological message list
-- for the selected contact. Returns the original messages table unchanged when
-- there is nothing to merge (no store, no state, no contact, no recent entry).
function ChannelContextMerger.Merge(messages, selectedContact, deps)
  deps = deps or {}
  if deps.enabled == false then
    return withoutChannelContext(messages)
  end
  local store = deps.channelMessageStore
  local state = deps.channelMessageState
  if not store or not state then
    return messages
  end
  if type(selectedContact) == "table" and selectedContact.channel ~= nil and not WHISPER_CHANNELS[selectedContact.channel] then
    return messages
  end

  local lookupName = lookupNameFor(selectedContact)
  if lookupName == nil then
    return messages
  end

  local entry = store.GetLatest(state, lookupName, deps.now)
  if not entry then
    return messages
  end

  local playerName = selectedContact.displayName or entry.playerName
  local conversation = deps.conversation
  if type(conversation) == "table" and conversation.messages == messages and WHISPER_CHANNELS[conversation.channel] then
    persistIntoConversation(conversation, entry, playerName)
    return messages
  end

  local channelMsg = cachedMessage
  if channelMsg == nil or cachedEntry ~= entry or cachedPlayerName ~= playerName then
    channelMsg = buildChannelMessage(entry, playerName)
    cachedEntry = entry
    cachedPlayerName = playerName
    cachedMessage = channelMsg
  end

  local result = {}
  for _, m in ipairs(messages) do
    result[#result + 1] = m
  end
  insertChronological(result, channelMsg)
  return result
end

-- The pane's one entry point: wires the live channel store and clock into Merge.
-- enabled == false is the "Show their last channel message" option turned off.
function ChannelContextMerger.ForPane(messages, selectedContact, conversation, enabled)
  return ChannelContextMerger.Merge(messages, selectedContact, {
    channelMessageStore = ns.ChannelMessageStore,
    channelMessageState = ns._channelMessageState,
    conversation = conversation,
    now = type(_G["time"]) == "function" and _G["time"]() or nil,
    enabled = enabled,
  })
end

ns.ConversationPaneChannelContextMerger = ChannelContextMerger
return ChannelContextMerger
