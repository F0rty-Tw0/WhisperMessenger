local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
local LivePresence = ns.LivePresence or require("WhisperMessenger.Model.LivePresence")

-- Outbound side of live presence: broadcasts typing state from the composer
-- and "Seen" receipts for the conversation on screen. Only talks to contacts
-- already known to run WhisperMessenger, so strangers never receive a byte.
local Sender = {}

local PREFIX = "WMRX"
-- Half the peer-side TTL: a re-send while the user keeps typing lands well
-- before the indicator on the other side expires.
local TYPING_RESEND_INTERVAL = 3

local function nowSeconds(runtime)
  if type(runtime.now) == "function" then
    return runtime.now() or 0
  end
  return 0
end

local function settingOn(runtime, key)
  local settings = runtime.accountState and runtime.accountState.settings
  return settings == nil or settings[key] ~= false
end

local function isRestricted(runtime)
  if type(runtime.isMythicLockdown) == "function" and runtime.isMythicLockdown() then
    return true
  end
  if type(runtime.isCompetitiveContent) == "function" and runtime.isCompetitiveContent() then
    return true
  end
  return false
end

local function conversationFor(runtime, key)
  local conversations = runtime.store and runtime.store.conversations
  if type(conversations) ~= "table" or key == nil then
    return nil
  end
  return conversations[key]
end

local function resolveGameAccountID(runtime, conversation)
  local accountInfo = BNetResolver.ResolveAccountInfo(runtime.bnetApi, conversation.bnetAccountID, conversation.guid, conversation.battleTag)
  local gameInfo = accountInfo and accountInfo.gameAccountInfo
  local gameAccountID = BNetResolver.SanitizeAccountID(gameInfo and gameInfo.gameAccountID)
  if type(gameAccountID) ~= "number" then
    return nil
  end
  return gameAccountID
end

local function send(runtime, conversation, payload)
  if conversation == nil or payload == nil then
    return false
  end
  if not AddonComm.RegisterPrefix(runtime.chatApi, PREFIX) then
    return false
  end
  if conversation.channel == "BN" then
    local gameAccountID = resolveGameAccountID(runtime, conversation)
    if gameAccountID == nil then
      return false
    end
    return AddonComm.SendBNet(runtime.bnetApi, PREFIX, payload, gameAccountID)
  end
  if conversation.channel ~= nil and conversation.channel ~= "WOW" then
    return false
  end
  return AddonComm.Send(runtime.chatApi, PREFIX, payload, conversation.displayName or conversation.contactDisplayName)
end

-- Called on every composer text change. Sends a throttled "typing" while the
-- box has text and one "stopped" when it empties or the selection changes.
function Sender.OnComposerText(runtime, contact, text)
  if type(runtime) ~= "table" then
    return false
  end
  local key = type(contact) == "table" and contact.conversationKey or nil
  local hasText = type(text) == "string" and text ~= "" and string.sub(text, 1, 1) ~= "/"
  local out = runtime.typingOut
  if out == nil then
    out = {}
    runtime.typingOut = out
  end

  local sentStop = false
  if out.active and (not hasText or out.conversationKey ~= key) then
    if not isRestricted(runtime) then
      send(runtime, conversationFor(runtime, out.conversationKey), LivePresence.EncodeTyping(false))
    end
    out.active = false
    out.conversationKey = nil
    sentStop = true
  end
  if not hasText then
    return sentStop
  end
  if not settingOn(runtime, "shareTypingStatus") or isRestricted(runtime) or not LivePresence.HasPeer(runtime, key) then
    return sentStop
  end
  local conversation = conversationFor(runtime, key)
  if conversation == nil then
    return sentStop
  end

  local now = nowSeconds(runtime)
  if out.active and out.conversationKey == key and now - (out.lastSentAt or 0) < TYPING_RESEND_INTERVAL then
    return sentStop
  end
  if not send(runtime, conversation, LivePresence.EncodeTyping(true)) then
    return sentStop
  end
  out.active = true
  out.conversationKey = key
  out.lastSentAt = now
  return true
end

-- Called after every window refresh with the conversation currently on
-- screen. Receipts are best-effort: a failed send is not retried, so a
-- refresh storm can never turn into an addon-message storm.
function Sender.SyncReadReceipts(runtime, selectedContact)
  if type(runtime) ~= "table" or type(selectedContact) ~= "table" then
    return false
  end
  local key = selectedContact.conversationKey
  if key == nil or not settingOn(runtime, "shareReadReceipts") or isRestricted(runtime) or not LivePresence.HasPeer(runtime, key) then
    return false
  end
  local conversation = conversationFor(runtime, key)
  local message = LivePresence.NextReceipt(conversation)
  if message == nil then
    return false
  end
  message.receiptSentAt = nowSeconds(runtime)
  return send(runtime, conversation, LivePresence.EncodeSeen(message.wireId)) == true
end

Sender.TYPING_RESEND_INTERVAL = TYPING_RESEND_INTERVAL

ns.BootstrapLivePresenceSender = Sender

return Sender
