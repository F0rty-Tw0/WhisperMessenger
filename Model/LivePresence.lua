local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Live presence between two WhisperMessenger users: typing indicators and
-- "Seen" receipts. Payloads ride the existing WMRX addon-message prefix, so
-- decoding any WMRX payload also proves the sender runs the addon (a "peer").
--
-- Wire format (version 1):
--   1|T|1      typing started        1|T|0   typing stopped
--   1|S|<id>   newest incoming message with wire id <id> has been seen
local LivePresence = {}

local VERSION = "1"
local TYPING_TTL = 6

local function isWireId(value)
  return type(value) == "string" and #value > 0 and #value <= 32 and string.match(value, "^[A-Za-z0-9]+$") ~= nil
end

function LivePresence.EncodeTyping(active)
  return VERSION .. "|T|" .. (active and "1" or "0")
end

function LivePresence.EncodeSeen(wireId)
  if not isWireId(wireId) then
    return nil
  end
  return VERSION .. "|S|" .. wireId
end

function LivePresence.Decode(payload)
  if type(payload) ~= "string" then
    return nil
  end
  local version, kind, value, extra = string.match(payload, "^([^|]*)|([^|]*)|([^|]*)(.*)$")
  if version ~= VERSION or extra ~= "" then
    return nil
  end
  if kind == "T" then
    if value == "1" then
      return { type = "typing", active = true }
    end
    if value == "0" then
      return { type = "typing", active = false }
    end
    return nil
  end
  if kind == "S" and isWireId(value) then
    return { type = "seen", wireId = value }
  end
  return nil
end

local function conversationFor(state, key)
  local conversations = type(state) == "table" and state.store and state.store.conversations
  if type(conversations) ~= "table" or key == nil then
    return nil
  end
  return conversations[key]
end

-- Peers are remembered in the runtime as soon as any payload arrives (the
-- conversation may not exist yet) and persisted on the conversation record
-- once it does, so the flag survives a reload.
function LivePresence.RecordPeer(state, key)
  if type(state) ~= "table" or key == nil then
    return false
  end
  state.livePresencePeers = state.livePresencePeers or {}
  state.livePresencePeers[key] = true
  local conversation = conversationFor(state, key)
  if conversation then
    conversation.peerHasAddon = true
  end
  return true
end

function LivePresence.HasPeer(state, key)
  if type(state) ~= "table" or key == nil then
    return false
  end
  if state.livePresencePeers and state.livePresencePeers[key] then
    return true
  end
  local conversation = conversationFor(state, key)
  return conversation ~= nil and conversation.peerHasAddon == true
end

function LivePresence.SetTyping(state, key, active, now)
  if type(state) ~= "table" or key == nil then
    return false
  end
  local wasTyping = LivePresence.IsTyping(state, key, now)
  state.typingByConversation = state.typingByConversation or {}
  if active then
    state.typingByConversation[key] = (now or 0) + TYPING_TTL
  else
    state.typingByConversation[key] = nil
  end
  return wasTyping ~= (active == true)
end

function LivePresence.IsTyping(state, key, now)
  local typing = type(state) == "table" and state.typingByConversation or nil
  local expiresAt = typing and key and typing[key] or nil
  return expiresAt ~= nil and (now or 0) < expiresAt
end

-- Seconds until the typing indicator expires, or 0 when not typing / expired.
function LivePresence.TypingRemaining(state, key, now)
  local typing = type(state) == "table" and state.typingByConversation or nil
  local expiresAt = typing and key and typing[key] or nil
  if expiresAt == nil then
    return 0
  end
  local remaining = expiresAt - (now or 0)
  if remaining <= 0 then
    return 0
  end
  return remaining
end

-- Seeing a message implies seeing everything sent before it, so mark the
-- target and every earlier unseen outgoing message. Returns how many changed.
function LivePresence.MarkSeen(state, key, wireId, now)
  local conversation = conversationFor(state, key)
  if conversation == nil or not isWireId(wireId) then
    return 0
  end
  local messages = conversation.messages or {}
  local targetIndex
  for index = #messages, 1, -1 do
    local message = messages[index]
    if message.direction == "out" and message.wireId == wireId then
      targetIndex = index
      break
    end
  end
  if targetIndex == nil then
    return 0
  end

  local changed = 0
  for index = targetIndex, 1, -1 do
    local message = messages[index]
    if message.direction == "out" and message.kind == "user" and message.delivery ~= "blocked" then
      if message.seenAt ~= nil then
        break
      end
      message.seenAt = now or 0
      changed = changed + 1
    end
  end
  return changed
end

-- The newest incoming message that carries a wire id and has not been
-- receipted yet. Messages without a wire id came from someone without the
-- addon (or before their identity payload landed) and are skipped.
function LivePresence.NextReceipt(conversation)
  if type(conversation) ~= "table" then
    return nil
  end
  local messages = conversation.messages or {}
  for index = #messages, 1, -1 do
    local message = messages[index]
    if message.direction == "in" and message.kind == "user" and isWireId(message.wireId) then
      if message.receiptSentAt ~= nil then
        return nil
      end
      return message
    end
  end
  return nil
end

LivePresence.TYPING_TTL = TYPING_TTL
LivePresence.VERSION = VERSION

ns.LivePresence = LivePresence

return LivePresence
