local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")

-- Reply to a message in a character or Battle.net whisper.
--
-- Locally an outgoing message carries replyTo = { id, wireId, direction,
-- author, snippet }. The whisper itself stays plain text, so a recipient
-- without the addon sees exactly what was typed. A recipient with the addon
-- also gets a "reply link" on the WMRX prefix, reusing the message wire ids
-- the identity payload (1|I|<wireId>|<fp>) already established:
--
--   1|Q|<wireId of the reply>|<wireId of the quoted message>|<M|Y>
--
-- M = the quoted message is the sender's own, Y = it is the recipient's.
-- Older versions decode WMRX with the reaction and presence decoders only;
-- both reject kind "Q", and the payload is then dropped silently.
local MessageReplies = {}

local VERSION = "1"
local SNIPPET_CHARS = 60
local ELLIPSIS = "…"
local STAGE_TTL = 60
local STAGE_CAP = 8

local function isWireId(value)
  return type(value) == "string" and #value > 0 and #value <= 32 and string.match(value, "^[A-Za-z0-9]+$") ~= nil
end

local function buildSnippet(text)
  if type(text) ~= "string" then
    return ""
  end
  local plain = string.gsub(text, "|H.-|h(.-)|h", "%1")
  plain = string.gsub(plain, "|c%x%x%x%x%x%x%x%x", "")
  plain = string.gsub(plain, "|r", "")
  plain = string.gsub(plain, "|T.-|t", "")
  plain = string.gsub(plain, "|A.-|a", "")
  local capped = TextLimits.CapChars(plain, SNIPPET_CHARS)
  if capped ~= plain then
    return capped .. ELLIPSIS
  end
  return plain
end

-- author is nil for the player's own message ("You" at render time).
function MessageReplies.BuildTarget(message)
  return {
    id = message.id,
    wireId = message.wireId,
    direction = message.direction,
    author = message.direction == "in" and message.playerName or nil,
    snippet = buildSnippet(message.text),
  }
end

function MessageReplies.CanReply(channel, message)
  return (channel == "WOW" or channel == "BN")
    and type(message) == "table"
    and message.kind == "user"
    and (message.direction == "in" or message.direction == "out")
    and message.delivery == nil
end

-- Index of the quoted message in history, or nil once it has aged out.
function MessageReplies.Find(messages, replyTo)
  if type(messages) ~= "table" or type(replyTo) ~= "table" then
    return nil
  end
  for index = #messages, 1, -1 do
    local message = messages[index]
    if message.direction == replyTo.direction then
      if replyTo.wireId ~= nil and message.wireId == replyTo.wireId then
        return index
      end
      if replyTo.wireId == nil and replyTo.id ~= nil and message.id == replyTo.id then
        return index
      end
    end
  end
  return nil
end

function MessageReplies.EncodeLink(wireId, replyTo)
  if not isWireId(wireId) or type(replyTo) ~= "table" or not isWireId(replyTo.wireId) then
    return nil
  end
  local owner = replyTo.direction == "out" and "M" or "Y"
  return table.concat({ VERSION, "Q", wireId, replyTo.wireId, owner }, "|")
end

function MessageReplies.DecodeLink(payload)
  if type(payload) ~= "string" then
    return nil
  end
  local wireId, targetWireId, owner = string.match(payload, "^1|Q|([^|]*)|([^|]*)|([MY])$")
  if not isWireId(wireId) or not isWireId(targetWireId) then
    return nil
  end
  -- The sender's own message arrived here as incoming, and vice versa.
  return { wireId = wireId, targetWireId = targetWireId, targetDirection = owner == "M" and "in" or "out" }
end

local function attach(conversation, message, link)
  local messages = conversation and conversation.messages
  local index = MessageReplies.Find(messages, { wireId = link.targetWireId, direction = link.targetDirection })
  if index == nil then
    return false
  end
  message.replyTo = MessageReplies.BuildTarget(messages[index])
  return true
end

-- The link can beat the whisper (or its identity) here; park it briefly.
function MessageReplies.ApplyLink(state, conversationKey, link, now)
  local conversation = Store.Find(state.store, conversationKey)
  local messages = conversation and conversation.messages or {}
  for index = #messages, 1, -1 do
    local message = messages[index]
    if message.direction == "in" and message.wireId == link.wireId then
      return attach(conversation, message, link)
    end
  end
  state.replyLinksStaged = state.replyLinksStaged or {}
  local staged = state.replyLinksStaged
  if #staged >= STAGE_CAP then
    table.remove(staged, 1)
  end
  staged[#staged + 1] = { conversationKey = conversationKey, link = link, recordedAt = now or 0 }
  return false
end

-- Called once an incoming whisper has its wire id.
function MessageReplies.ClaimStaged(state, conversationKey, message, now)
  local staged = state.replyLinksStaged
  if type(staged) ~= "table" or type(message) ~= "table" or message.wireId == nil then
    return false
  end
  for index = #staged, 1, -1 do
    local entry = staged[index]
    if (now or 0) - entry.recordedAt > STAGE_TTL then
      table.remove(staged, index)
    elseif entry.conversationKey == conversationKey and entry.link.wireId == message.wireId then
      table.remove(staged, index)
      return attach(Store.Find(state.store, conversationKey), message, entry.link)
    end
  end
  return false
end

ns.MessageReplies = MessageReplies
return MessageReplies
