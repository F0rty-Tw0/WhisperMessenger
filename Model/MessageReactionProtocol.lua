local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Wire = ns.MessageReactionProtocolWire or require("WhisperMessenger.Model.MessageReactionProtocol.Wire")
local Fallback = ns.MessageReactionProtocolFallback or require("WhisperMessenger.Model.MessageReactionProtocol.Fallback")
local Decode = ns.MessageReactionProtocolDecode or require("WhisperMessenger.Model.MessageReactionProtocol.Decode")

local Protocol = {}

local MAX_PAYLOAD_BYTES = Wire.MAX_PAYLOAD_BYTES
local VERSION = Wire.VERSION
-- How long a side message waits for its whisper, and how far apart the
-- parts of one long whisper may arrive.
local PAIRING_TTL_SECONDS = 15

local isWireId = Wire.IsWireId
local isSafeGroupTarget = Wire.IsSafeGroupTarget

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

Protocol.IsReactionKey = Wire.IsReactionKey

Protocol._fingerprintComputeCount = 0

local function computeFingerprint(text)
  Protocol._fingerprintComputeCount = Protocol._fingerprintComputeCount + 1
  local hash = 5381
  for index = 1, #text do
    hash = (hash * 33 + string.byte(text, index)) % 4294967296
  end
  return string.format("%08x", math.floor(hash))
end

local lastFingerprintText
local lastFingerprint

-- Group ingest fingerprints the same line more than once; a one-entry memo
-- skips the repeat per-byte hash. The function is pure, so nothing invalidates.
function Protocol.Fingerprint(text)
  if type(text) ~= "string" then
    return computeFingerprint("")
  end
  if text ~= lastFingerprintText then
    lastFingerprint = computeFingerprint(text)
    lastFingerprintText = text
  end
  return lastFingerprint
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

Protocol.BuildGroupFallback = Fallback.BuildGroupFallback
Protocol.ParseGroupFallback = Fallback.ParseGroupFallback

function Protocol.BuildFallback(key, operation, sourceText, hintSuffix)
  return Protocol.BuildGroupFallback(key, operation, sourceText, hintSuffix)
end

function Protocol.ParseFallback(text)
  return Protocol.ParseGroupFallback(text)
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

Protocol.Decode = Decode.Decode

Protocol.IsWireId = isWireId
Protocol.IsFingerprint = Wire.IsFingerprint
Protocol.REACTION_KEYS = Wire.REACTION_KEYS
Protocol.MAX_PAYLOAD_BYTES = MAX_PAYLOAD_BYTES
Protocol.VERSION = VERSION
Protocol.PAIRING_TTL_SECONDS = PAIRING_TTL_SECONDS
Protocol.ADDON_HINT_SUFFIX = Fallback.ADDON_HINT_SUFFIX

ns.MessageReactionProtocol = Protocol
return Protocol
