local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
local Router = ns.EventRouter or require("WhisperMessenger.Core.EventRouter")
local Gateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local QuestLinkClassic = ns.UIHyperlinksQuestLinkClassic or require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")
local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local QuestLinkExchange = ns.QuestLinkExchange or require("WhisperMessenger.Model.QuestLinkExchange")

local QUEST_LINK_ADDON_PREFIX = "WMQL"

local SendHandler = {}

local function isCombatSendLocked(runtime)
  if runtime.isChatMessagingLocked and runtime.isChatMessagingLocked() then
    return true
  end

  -- Guard direct SendChatMessage usage during combat even when runtime-level
  -- lockdown queueing is disabled; insecure addon calls are blocked here.
  return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() or false
end

local function appendBlockedOutgoing(runtime, payload, reason)
  if runtime == nil or runtime.store == nil or payload == nil or payload.conversationKey == nil then
    return
  end

  local now = runtime.now and runtime.now() or 0
  local blockedMessage = {
    id = tostring(now),
    eventName = "WHISPERMESSENGER_OUTGOING_BLOCKED",
    direction = "out",
    kind = "user",
    text = payload.text,
    sentAt = now,
    guid = payload.guid,
    playerName = payload.displayName or payload.target,
    channel = payload.channel or "WOW",
    bnetAccountID = payload.bnetAccountID,
    gameAccountName = payload.gameAccountName,
    delivery = "blocked",
    blockedReason = reason,
  }

  if type(runtime.store.config) == "table" then
    Store.AppendOutgoing(runtime.store, payload.conversationKey, blockedMessage)
    return
  end

  runtime.store.conversations = runtime.store.conversations or {}
  local conversation = runtime.store.conversations[payload.conversationKey]
  if conversation == nil then
    conversation = { messages = {}, unreadCount = 0, lastPreview = nil, lastActivityAt = 0 }
    runtime.store.conversations[payload.conversationKey] = conversation
  end

  conversation.messages = conversation.messages or {}
  table.insert(conversation.messages, blockedMessage)
  conversation.lastPreview = blockedMessage.text
  conversation.lastActivityAt = blockedMessage.sentAt
  conversation.displayName = blockedMessage.playerName or conversation.displayName
  conversation.channel = blockedMessage.channel or conversation.channel
end

function SendHandler.HandleSend(runtime, payload, refreshWindow)
  runtime.sendStatusByConversation[payload.conversationKey] = nil

  -- Normalize quest links into the form that survives transmission on this
  -- flavor + channel:
  --   * Classic character whisper: `|H...|h` is stripped server-side, so we
  --     serialize hyperlinks back to plain `[Name (id)]` — the only form the
  --     wire preserves intact. Recipients running our addon re-link from the
  --     plain form; recipients without it still see the name and id.
  --   * Retail and Battle.net: keep the rich hyperlink so addon-less
  --     recipients get a clickable link directly from Blizzard's chat frame.
  if type(payload.text) == "string" then
    local isClassicCharacterWhisper = FlavorCompat.isClassic and (payload.channel == nil or payload.channel == "WOW")
    if isClassicCharacterWhisper then
      payload.text = QuestLinkClassic.Serialize(payload.text)
    else
      payload.text = QuestLinkClassic.Rewrite(payload.text)
    end
  end

  if isCombatSendLocked(runtime) then
    appendBlockedOutgoing(runtime, payload, "Lockdown")
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Lockdown")
    refreshWindow()
    return false
  end

  if runtime.isMythicLockdown and runtime.isMythicLockdown() then
    appendBlockedOutgoing(runtime, payload, "Mythic Lockdown")
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Mythic Lockdown")
    refreshWindow()
    return false
  end

  if runtime.isCompetitiveContent and runtime.isCompetitiveContent() then
    appendBlockedOutgoing(runtime, payload, "Competitive Content")
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Competitive Content")
    refreshWindow()
    return false
  end

  local sendAvailable
  if payload.channel == "BN" then
    sendAvailable = payload.bnetAccountID ~= nil and Gateway.CanSendBattleNetWhisper(runtime.bnetApi)
  else
    sendAvailable = Gateway.CanSendCharacterWhisper(runtime.chatApi)
  end

  if not sendAvailable then
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Send unavailable")
    refreshWindow()
    return false
  end

  local pendingConversationKey = Router.RecordPendingSend(runtime, payload, payload.text)
  local callOk, sendOk
  if payload.channel == "BN" then
    callOk, sendOk = pcall(Gateway.SendBattleNetWhisper, runtime.bnetApi, payload.bnetAccountID, payload.text)

    -- Classic Battle.net character whispers also strip the `(id)` from
    -- `[Name (id)]` and the `|H...|h` envelope. Ship the same paired side
    -- channel as the WoW whisper path, but via BNSendGameData so it routes
    -- over Battle.net to the friend's bnetAccountID. Receivers with our
    -- addon splice the link back in on BN_CHAT_MSG_ADDON.
    if callOk and sendOk ~= false and FlavorCompat.isClassic and payload.bnetAccountID ~= nil then
      local encoded = QuestLinkExchange.Encode(payload.text)
      if encoded ~= nil then
        AddonComm.RegisterPrefix(runtime.chatApi, QUEST_LINK_ADDON_PREFIX)
        AddonComm.SendBNet(runtime.bnetApi, QUEST_LINK_ADDON_PREFIX, encoded, payload.bnetAccountID)
      end
    end
  else
    -- SendChatMessage is hardware-event-protected; pcall breaks the
    -- propagation chain causing ADDON_ACTION_FORBIDDEN.  Call directly
    -- and let WoW's error handler surface failures instead.
    Gateway.SendCharacterWhisper(runtime.chatApi, payload.target, payload.text)
    callOk = true
    sendOk = true

    -- Side channel: on Classic the chat protocol strips both the `|H`
    -- envelope AND the `(id)` from `[Name (id)]` patterns, leaving the
    -- recipient with just `[Name]`. We ship the id+name pairs over the
    -- addon-message wire so a recipient running our addon can splice the
    -- clickable link back in. Best-effort — failure here doesn't fail the
    -- whisper itself.
    if FlavorCompat.isClassic then
      local encoded = QuestLinkExchange.Encode(payload.text)
      if encoded ~= nil and payload.target ~= nil and payload.target ~= "" then
        AddonComm.RegisterPrefix(runtime.chatApi, QUEST_LINK_ADDON_PREFIX)
        AddonComm.Send(runtime.chatApi, QUEST_LINK_ADDON_PREFIX, encoded, payload.target)
      end
    end
  end

  if not callOk or sendOk == false then
    local pending = runtime.pendingOutgoing[pendingConversationKey]
    if pending and #pending > 0 then
      table.remove(pending, #pending)
      if #pending == 0 then
        runtime.pendingOutgoing[pendingConversationKey] = nil
      end
    end

    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Send failed")
    refreshWindow()
    return false
  end

  refreshWindow()
  return true
end

ns.BootstrapSendHandler = SendHandler
return SendHandler
