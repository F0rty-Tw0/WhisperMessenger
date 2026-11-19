local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
local QuestLinkExchange = ns.QuestLinkExchange or require("WhisperMessenger.Model.QuestLinkExchange")
local QuestLinkText = ns.QuestLinkText or require("WhisperMessenger.Model.QuestLinkText")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")

-- What every whisper branch of the router shares: the contact and stored
-- message built from a chat payload, and the conversation lookups.
local WhisperMessage = {}

local function checkCensored(lineID)
  local chatApi = _G.C_ChatInfo
  if chatApi == nil or type(chatApi.IsChatLineCensored) ~= "function" then
    return nil
  end
  if lineID == nil then
    return nil
  end
  local ok, censored = pcall(chatApi.IsChatLineCensored, lineID)
  if ok and censored == true then
    return true
  end
  return nil
end

local function buildConversationContact(state, payload)
  if payload.channel == "BN" then
    if payload.bnetAccountID == nil then
      return nil, nil
    end

    local contact = Identity.FromBattleNet(payload.bnetAccountID, payload.accountInfo, payload.playerInfo)
    if contact.canonicalName == "" then
      return nil, nil
    end
    local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
    return contact, conversationKey
  end

  -- Only a nil-check here: comparing a tainted chat payload against a literal
  -- string trips Blizzard's secret-string protection. We defer the "empty
  -- name" rejection to the canonicalName check below — normalizeName pcalls
  -- Ambiguate/string.lower, so tainted names degrade to "" safely.
  if payload.playerName == nil then
    return nil, nil
  end

  local contact = Identity.FromWhisper(payload.playerName, payload.guid, payload.playerInfo)
  if contact.canonicalName == "" then
    return nil, nil
  end
  local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
  return contact, conversationKey
end

-- A whisper that went through (either way) outranks the whisper check's
-- "Offline" for this long.
local WHISPER_PROOF_SECONDS = 5 * 60

local function isWhisperProofFresh(confirmed, now)
  return confirmed.confirmedAt ~= nil and now - confirmed.confirmedAt < WHISPER_PROOF_SECONDS
end

local function confirmWhisperAvailability(state, payload, contact)
  local guid = payload.guid or (contact and contact.guid or nil)
  if guid == nil then
    return
  end
  -- A replayed whisper (held by the chat lock) proves the time it went through:
  -- too old proves nothing now, and it never moves a newer proof back in time.
  local now = state.now and state.now() or 0
  local at = payload.replayedAt or now
  if now - at >= WHISPER_PROOF_SECONDS then
    return
  end
  state.availabilityByGUID = state.availabilityByGUID or {}
  local existing = state.availabilityByGUID[guid]
  if existing and existing.confirmedByWhisper and existing.confirmedAt and existing.confirmedAt >= at then
    return
  end
  local availability = Availability.FromStatus("CanWhisper")
  availability.confirmedByWhisper = true
  availability.confirmedAt = at
  state.availabilityByGUID[guid] = availability
end

local function setIfPresent(message, field, value)
  if value ~= nil then
    message[field] = value
  end
end

local function buildMessage(state, payload, contact, direction, kind, sentAt)
  local senderClassTag
  local senderName
  if direction == "out" then
    -- Stamp the sending character's class and name so the bubble icon and
    -- "You — <char>" label survive relogging to another character.
    senderClassTag = LocalPlayer.ClassTag()
    senderName = LocalPlayer.Name()
  end
  -- WoW Classic's character-whisper protocol strips real quest hyperlinks
  -- on the wire, so CHAT_MSG_WHISPER and CHAT_MSG_WHISPER_INFORM can arrive
  -- carrying plain `[Name (id)]` text even when the original outgoing
  -- message was a hyperlink. Rewrite here so bubbles always render a
  -- clickable link. Idempotent on already-hyperlinked text.
  local messageText = payload.text
  if type(messageText) == "string" then
    messageText = QuestLinkText.Rewrite(messageText)
    -- Classic strips the `(id)` too, leaving just `[Name]`. The paired
    -- addon-message side channel carries the id back; splice it in here.
    -- Character whispers key the inbox by player name; BNet whispers key by
    -- bnetAccountID so the link survives even if the friend hops characters.
    if direction == "in" then
      local senderKey
      if payload.channel == "BN" and payload.bnetAccountID ~= nil then
        senderKey = "bn:" .. tostring(payload.bnetAccountID)
      elseif payload.playerName then
        senderKey = payload.playerName
      end
      if senderKey then
        local now = state.now and state.now() or 0
        messageText = QuestLinkExchange.Splice(state, senderKey, messageText, now)
      end
    end
  end
  local message = {
    id = tostring(payload.lineID or sentAt),
    direction = direction,
    kind = kind,
    text = messageText,
    sentAt = sentAt,
    channel = (contact and contact.channel) or payload.channel or "WOW",
  }
  -- The optional fields go on one at a time: a table constructor reserves a
  -- slot for every field it names, nil or not, which doubled the table of
  -- every whisper kept in the session.
  setIfPresent(message, "lineID", payload.lineID)
  setIfPresent(message, "guid", payload.guid or (contact and contact.guid or nil))
  setIfPresent(message, "playerName", (contact and contact.displayName) or payload.playerName)
  setIfPresent(message, "bnetAccountID", (contact and contact.bnetAccountID) or payload.bnetAccountID)
  setIfPresent(message, "battleTag", (contact and contact.battleTag) or payload.battleTag)
  setIfPresent(message, "gameAccountName", (contact and contact.gameAccountName) or payload.gameAccountName)
  setIfPresent(message, "className", (contact and contact.className) or payload.className)
  setIfPresent(message, "classTag", (contact and contact.classTag) or payload.classTag)
  setIfPresent(message, "senderClassTag", senderClassTag)
  setIfPresent(message, "senderName", senderName)
  setIfPresent(message, "raceName", (contact and contact.raceName) or payload.raceName)
  setIfPresent(message, "raceTag", (contact and contact.raceTag) or payload.raceTag)
  setIfPresent(message, "factionName", (contact and contact.factionName) or payload.factionName)
  setIfPresent(message, "isCensored", payload.isCensored or checkCensored(payload.lineID))
  return message
end

local function conversationWithKey(state, conversationKey)
  local conversation = conversationKey and state.store.conversations[conversationKey] or nil
  if conversation then
    conversation.conversationKey = conversationKey
  end
  return conversation
end

-- On screen: the window's own answer when it gives one, else the selected key.
local function isOpen(state, conversationKey)
  if state.isConversationOpen then
    return state.isConversationOpen(conversationKey) == true
  end
  return state.activeConversationKey == conversationKey
end

WhisperMessage.BuildConversationContact = buildConversationContact
WhisperMessage.IsWhisperProofFresh = isWhisperProofFresh
WhisperMessage.ConfirmWhisperAvailability = confirmWhisperAvailability
WhisperMessage.BuildMessage = buildMessage
WhisperMessage.ConversationWithKey = conversationWithKey
WhisperMessage.IsOpen = isOpen

ns.EventRouterWhisperMessage = WhisperMessage

return WhisperMessage
