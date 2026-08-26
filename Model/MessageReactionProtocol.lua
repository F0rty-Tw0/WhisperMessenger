local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = {}

local MAX_PAYLOAD_BYTES = 255
local MAX_WHISPER_BYTES = 255
local VERSION = "1"
local ELLIPSIS = "…"
local OPEN_QUOTE = "“"
local CLOSE_QUOTE = "”"

local REACTION_KEYS = {
  "heart",
  "thumbsup",
  "laugh",
  "smile",
  "wink",
  "clap",
  "party",
  "fire",
  "gg",
  "wow",
  "sad",
  "cry",
  "angry",
  "thinking",
  "eyes",
  "question",
  "pray",
  "skull",
}

local reactionKeySet = {}
for _, key in ipairs(REACTION_KEYS) do
  reactionKeySet[key] = true
end

local function isWireId(value)
  return type(value) == "string" and #value > 0 and #value <= 32 and string.match(value, "^[A-Za-z0-9]+$") ~= nil
end

local function isFingerprint(value)
  return type(value) == "string" and string.match(value, "^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") ~= nil
end

local function isSafeGroupTarget(value)
  return type(value) == "string" and string.find(value, "|", 1, true) == nil
end

local function splitPayload(payload)
  local fields = {}
  local startIndex = 1
  while true do
    local separator = string.find(payload, "|", startIndex, true)
    if separator == nil then
      table.insert(fields, string.sub(payload, startIndex))
      break
    end
    table.insert(fields, string.sub(payload, startIndex, separator - 1))
    startIndex = separator + 1
  end
  return fields
end

local function base36(value)
  local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
  local number = math.max(0, math.floor(tonumber(value) or 0))
  if number == 0 then
    return "0"
  end

  local parts = {}
  while number > 0 do
    local remainder = number % 36
    table.insert(parts, 1, string.sub(digits, remainder + 1, remainder + 1))
    number = math.floor(number / 36)
  end
  return table.concat(parts)
end

local function wireIdExists(state, candidate)
  local conversations = state and state.store and state.store.conversations
  if type(conversations) ~= "table" then
    return false
  end
  for _, conversation in pairs(conversations) do
    for _, message in ipairs(conversation.messages or {}) do
      if message.wireId == candidate then
        return true
      end
    end
  end
  return false
end

local function utf8SequenceWidth(firstByte)
  if firstByte < 0x80 then
    return 1
  end
  if firstByte >= 0xC2 and firstByte <= 0xDF then
    return 2
  end
  if firstByte >= 0xE0 and firstByte <= 0xEF then
    return 3
  end
  if firstByte >= 0xF0 and firstByte <= 0xF4 then
    return 4
  end
  return 1
end

local function utf8Prefix(text, maxBytes)
  local cursor = 1
  local lastComplete = 0
  while cursor <= #text do
    local width = utf8SequenceWidth(string.byte(text, cursor))
    if cursor + width - 1 > maxBytes then
      break
    end
    lastComplete = cursor + width - 1
    cursor = cursor + width
  end
  return string.sub(text, 1, lastComplete)
end

function Protocol.IsReactionKey(key)
  return reactionKeySet[key] == true
end

function Protocol.Fingerprint(text)
  if type(text) ~= "string" then
    text = ""
  end
  local hash = 5381
  for index = 1, #text do
    hash = (hash * 33 + string.byte(text, index)) % 4294967296
  end
  return string.format("%08x", math.floor(hash))
end

function Protocol.NewWireId(state, now)
  state = state or {}
  local sequence = (tonumber(state.messageReactionWireSequence) or 0) + 1
  local prefix = base36(now)
  local candidate = prefix .. base36(sequence)
  while wireIdExists(state, candidate) do
    sequence = sequence + 1
    candidate = prefix .. base36(sequence)
  end
  state.messageReactionWireSequence = sequence
  return candidate
end

function Protocol.BuildFallback(key, operation, sourceText)
  return Protocol.BuildGroupFallback(key, operation, sourceText)
end

function Protocol.ParseFallback(text)
  return Protocol.ParseGroupFallback(text)
end

function Protocol.BuildGroupFallback(key, operation, sourceText)
  if not Protocol.IsReactionKey(key) then
    return nil
  end
  if operation ~= "set" and operation ~= "remove" then
    return nil
  end
  if type(sourceText) ~= "string" then
    sourceText = ""
  end

  local action
  if operation == "set" then
    action = "reacted :" .. key .. ": to: "
  else
    action = "removed :" .. key .. ": from: "
  end
  local prefix = action .. OPEN_QUOTE
  local suffix = CLOSE_QUOTE
  local available = MAX_PAYLOAD_BYTES - #prefix - #suffix
  if available < 0 then
    return nil
  end

  local excerpt = sourceText
  if #excerpt > available then
    local textBudget = available - #ELLIPSIS
    if textBudget < 0 then
      return nil
    end
    excerpt = utf8Prefix(excerpt, textBudget) .. ELLIPSIS
  end
  return prefix .. excerpt .. suffix
end

function Protocol.ParseGroupFallback(text)
  if type(text) ~= "string" or #text > MAX_PAYLOAD_BYTES then
    return nil
  end

  local key, sourceExcerpt = string.match(text, "^reacted :([a-z]+): to: “(.*)” *$")
  local operation = "set"
  if key == nil then
    key, sourceExcerpt = string.match(text, "^removed :([a-z]+): from: “(.*)” *$")
    operation = "remove"
  end
  if key == nil or not Protocol.IsReactionKey(key) then
    return nil
  end
  return {
    operation = operation,
    key = key,
    sourceExcerpt = sourceExcerpt,
    truncated = string.sub(sourceExcerpt, -#ELLIPSIS) == ELLIPSIS,
  }
end

local function encodeReactionPayload(kind, operation, key, wireId, sourceText, fallbackText, targetGuid, targetName)
  local operationCode
  if operation == "set" then
    operationCode = "S"
  elseif operation == "remove" then
    operationCode = "D"
  else
    return nil
  end
  if not Protocol.IsReactionKey(key) or (wireId ~= nil and not isWireId(wireId)) or type(fallbackText) ~= "string" then
    return nil
  end

  local fields = {
    VERSION,
    kind,
    operationCode,
    key,
    wireId or "",
    Protocol.Fingerprint(sourceText),
    Protocol.Fingerprint(fallbackText),
  }
  if targetGuid ~= nil then
    fields[#fields + 1] = targetGuid
    fields[#fields + 1] = targetName
  end
  local payload = table.concat(fields, "|")
  if #payload > MAX_PAYLOAD_BYTES then
    return nil
  end
  return payload
end

function Protocol.EncodeIdentity(wireId, sourceText)
  if not isWireId(wireId) then
    return nil
  end
  local payload = table.concat({ VERSION, "I", wireId, Protocol.Fingerprint(sourceText) }, "|")
  if #payload > MAX_PAYLOAD_BYTES then
    return nil
  end
  return payload
end

function Protocol.EncodeReaction(operation, key, wireId, sourceText, fallbackText)
  return encodeReactionPayload("R", operation, key, wireId, sourceText, fallbackText)
end

function Protocol.EncodeGroupReaction(operation, key, wireId, sourceText, fallbackText, targetGuid, targetName)
  if targetGuid == nil then
    targetGuid = ""
  end
  if targetName == nil then
    targetName = ""
  end
  if not isSafeGroupTarget(targetGuid) or not isSafeGroupTarget(targetName) then
    return nil
  end
  if targetGuid == "" and targetName == "" then
    return nil
  end

  return encodeReactionPayload("G", operation, key, wireId, sourceText, fallbackText, targetGuid, targetName)
end

function Protocol.Decode(payload)
  if type(payload) ~= "string" or payload == "" or #payload > MAX_PAYLOAD_BYTES then
    return nil
  end
  local fields = splitPayload(payload)
  if fields[1] ~= VERSION then
    return nil
  end

  if fields[2] == "I" then
    if #fields ~= 4 or not isWireId(fields[3]) or not isFingerprint(fields[4]) then
      return nil
    end
    return {
      type = "identity",
      wireId = fields[3],
      sourceFingerprint = fields[4],
    }
  end

  if fields[2] == "G" then
    if #fields ~= 9 then
      return nil
    end
    local operation
    if fields[3] == "S" then
      operation = "set"
    elseif fields[3] == "D" then
      operation = "remove"
    else
      return nil
    end
    if not Protocol.IsReactionKey(fields[4]) then
      return nil
    end
    if fields[5] ~= "" and not isWireId(fields[5]) then
      return nil
    end
    if not isFingerprint(fields[6]) or not isFingerprint(fields[7]) then
      return nil
    end
    if not isSafeGroupTarget(fields[8]) or not isSafeGroupTarget(fields[9]) then
      return nil
    end
    if fields[8] == "" and fields[9] == "" then
      return nil
    end
    return {
      type = "groupReaction",
      operation = operation,
      key = fields[4],
      wireId = fields[5] ~= "" and fields[5] or nil,
      sourceFingerprint = fields[6],
      fallbackFingerprint = fields[7],
      targetGuid = fields[8],
      targetName = fields[9],
    }
  end

  if fields[2] ~= "R" or #fields ~= 7 then
    return nil
  end
  local operation
  if fields[3] == "S" then
    operation = "set"
  elseif fields[3] == "D" then
    operation = "remove"
  else
    return nil
  end
  if not Protocol.IsReactionKey(fields[4]) then
    return nil
  end
  if fields[5] ~= "" and not isWireId(fields[5]) then
    return nil
  end
  if not isFingerprint(fields[6]) or not isFingerprint(fields[7]) then
    return nil
  end
  return {
    type = "reaction",
    operation = operation,
    key = fields[4],
    wireId = fields[5] ~= "" and fields[5] or nil,
    sourceFingerprint = fields[6],
    fallbackFingerprint = fields[7],
  }
end

Protocol.REACTION_KEYS = REACTION_KEYS
Protocol.MAX_PAYLOAD_BYTES = MAX_PAYLOAD_BYTES
Protocol.MAX_WHISPER_BYTES = MAX_WHISPER_BYTES
Protocol.VERSION = VERSION

ns.MessageReactionProtocol = Protocol
return Protocol
