local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local QuestLinkExchange = ns.QuestLinkExchange or require("WhisperMessenger.Model.QuestLinkExchange")
local QuestLinkText = ns.QuestLinkText or require("WhisperMessenger.Model.QuestLinkText")
local MessageReactionProtocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local LivePresence = ns.LivePresence or require("WhisperMessenger.Model.LivePresence")
local GroupChatIngest = ns.GroupChatIngest or require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local MessageReplies = ns.MessageReplies or require("WhisperMessenger.Model.MessageReplies")
local PartMerge = ns.EventRouterPartMerge or require("WhisperMessenger.Core.EventRouter.PartMerge")
local AddonGreetingIngest = ns.EventRouterAddonGreetingIngest or require("WhisperMessenger.Core.EventRouter.AddonGreetingIngest")
local WhisperMessage = ns.EventRouterWhisperMessage or require("WhisperMessenger.Core.EventRouter.WhisperMessage")

local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local QUEST_LINK_ADDON_PREFIX = AddonComm.PREFIX_QUEST_LINK
local REACTION_ADDON_PREFIX = AddonComm.PREFIX_REACTION
local ADDON_GREETING_PREFIX = AddonComm.PREFIX_ADDON_GREETING
local CRAFT_SCAN_PREFIX = AddonComm.PREFIX_CRAFT_SCAN

local buildConversationContact = WhisperMessage.BuildConversationContact
local conversationWithKey = WhisperMessage.ConversationWithKey

-- The addon side channel: reactions, typing, read receipts, reply links,
-- part manifests, quest links and addon greetings.
local AddonMessage = {}

local function battleNetReactionSenderKey(state, payload)
  if payload.bnetAccountID ~= nil then
    local canonicalKey = "bn:" .. tostring(payload.bnetAccountID)
    if payload.gameAccountID ~= nil then
      MessageReactions.AssociateSenderAlias(state, "bngame:" .. tostring(payload.gameAccountID), canonicalKey)
    end
    return canonicalKey
  end
  if payload.gameAccountID ~= nil then
    return MessageReactions.ResolveSenderAlias(state, "bngame:" .. tostring(payload.gameAccountID))
  end
  return nil
end

local function resolveWhisperReactionConversation(state, playerName, computedConversationKey)
  return Identity.ResolveWhisperConversation(state, playerName, "WOW") or computedConversationKey
end

local function recordConvertedReactionFallbackActivity(state, result, fallbackConversationKey)
  if result.changed ~= true or result.operation ~= "set" then
    return
  end
  local conversationKey = result.conversationKey or fallbackConversationKey
  if conversationKey == nil then
    return
  end
  Store.RecordIncomingActivity(state.store, conversationKey, result.incomingFallbackMessage, result.incomingFallbackIsActive)
end

local function reactionSenderContext(state, payload, isBattleNet)
  if isBattleNet then
    local senderKey = battleNetReactionSenderKey(state, payload)
    if senderKey == nil then
      return nil, nil, nil, nil, nil
    end
    local conversationKey = payload.bnetAccountID ~= nil and Identity.ResolveWhisperConversation(state, payload.bnetAccountID, "BN") or nil
    local conversation = conversationKey and state.store.conversations[conversationKey] or nil
    local actorName = conversation
        and (conversation.displayName or conversation.contactDisplayName or conversation.battleTag or conversation.gameAccountName)
      or tostring(payload.bnetAccountID or senderKey)
    return senderKey, conversationKey, actorName, conversationKey, senderKey
  end

  if type(payload.playerName) ~= "string" then
    return nil, nil, nil, nil, nil
  end
  local contact, computedConversationKey = buildConversationContact(state, payload)
  if contact == nil then
    return nil, nil, nil, nil, nil
  end
  local conversationKey = resolveWhisperReactionConversation(state, payload.playerName, computedConversationKey)
  local conversation = state.store.conversations[conversationKey]
  local actorName = conversation and (conversation.displayName or conversation.contactDisplayName) or contact.displayName or payload.playerName
  return conversationKey, conversationKey, actorName, conversationKey, conversationKey
end

local function handlePresence(state, conversationKey, presence, now)
  local typingChanged
  if presence.type == "typing" then
    typingChanged = LivePresence.SetTyping(state, conversationKey, presence.active, now)
  elseif presence.type == "seen" then
    if LivePresence.MarkSeen(state, conversationKey, presence.wireId, now) == 0 then
      return nil
    end
  end
  local conversation = conversationWithKey(state, conversationKey)
  if conversation == nil then
    return nil
  end
  local meta = { presence = presence.type, typingActive = presence.active }
  if presence.type == "typing" then
    meta.typingChanged = typingChanged
  end
  return conversation, meta
end

local function handleReactionMetadata(state, payload, isBattleNet)
  local metadata = MessageReactionProtocol.Decode(payload.text)
  local presence = metadata == nil and LivePresence.Decode(payload.text) or nil
  local replyLink = metadata == nil and presence == nil and MessageReplies.DecodeLink(payload.text) or nil
  if metadata == nil and presence == nil and replyLink == nil then
    return nil
  end
  local senderKey, conversationKey, actorName, identityConversationKey, reactionSenderKey = reactionSenderContext(state, payload, isBattleNet)
  if senderKey == nil then
    return nil
  end
  local now = state.now and state.now() or 0
  -- Any well-formed WMRX payload proves the sender runs the addon.
  LivePresence.RecordPeer(state, conversationKey)
  if replyLink ~= nil then
    if MessageReplies.ApplyLink(state, conversationKey, replyLink, now) then
      return conversationWithKey(state, conversationKey)
    end
    return nil
  end
  if metadata == nil then
    return handlePresence(state, conversationKey, presence, now)
  end
  if metadata.type == "identity" or metadata.type == "manifest" then
    local paired = PartMerge.RecordIdentity(state, senderKey, identityConversationKey, metadata, now)
    if paired == nil then
      return nil
    end
    -- The whisper now carries a wire id, so the window can send its receipt.
    local conversation = conversationWithKey(state, conversationKey)
    if conversation == nil then
      return nil
    end
    return conversation, { presence = "identity" }
  end
  if metadata.type ~= "reaction" then
    return nil
  end
  local result = MessageReactions.RecordOperation(state, reactionSenderKey, conversationKey, actorName, metadata, "out", now, QuestLinkText.Serialize)

  if result and result.converted then
    local resolvedConversationKey = result.conversationKey or conversationKey
    recordConvertedReactionFallbackActivity(state, result, resolvedConversationKey)

    return conversationWithKey(state, resolvedConversationKey),
      {
        reactionControl = true,
        reactionChanged = result.changed == true,
        reactionOperation = result.operation,
      }
  end
  return nil
end

-- CHAT_MSG_ADDON, after the router's secret-string check.
function AddonMessage.HandleCharacter(state, payload)
  if payload.prefix == REACTION_ADDON_PREFIX and payload.channel == "WHISPER" then
    return handleReactionMetadata(state, payload, false)
  end
  if payload.prefix == REACTION_ADDON_PREFIX and ChannelType.ADDON_GROUP_CHANNELS[payload.channel] then
    return GroupChatIngest.HandleAddonEvent(state, payload)
  end
  if payload.prefix == QUEST_LINK_ADDON_PREFIX and payload.channel == "WHISPER" and type(payload.playerName) == "string" then
    local now = state.now and state.now() or 0
    QuestLinkExchange.RecordIncoming(state, payload.playerName, payload.text, now)
  end
  if payload.prefix == ADDON_GREETING_PREFIX or payload.prefix == CRAFT_SCAN_PREFIX then
    return AddonGreetingIngest.HandleAddonMessage(state, payload)
  end
  return nil
end

-- BN_CHAT_MSG_ADDON, after the router's secret-string check.
function AddonMessage.HandleBattleNet(state, payload)
  if payload.prefix == REACTION_ADDON_PREFIX then
    return handleReactionMetadata(state, payload, true)
  end
  if payload.prefix == QUEST_LINK_ADDON_PREFIX and payload.bnetAccountID ~= nil then
    local now = state.now and state.now() or 0
    QuestLinkExchange.RecordIncoming(state, "bn:" .. tostring(payload.bnetAccountID), payload.text, now)
  end
  return nil
end

AddonMessage.BattleNetReactionSenderKey = battleNetReactionSenderKey
AddonMessage.ResolveWhisperReactionConversation = resolveWhisperReactionConversation
AddonMessage.RecordConvertedReactionFallbackActivity = recordConvertedReactionFallbackActivity

ns.EventRouterAddonMessage = AddonMessage

return AddonMessage
