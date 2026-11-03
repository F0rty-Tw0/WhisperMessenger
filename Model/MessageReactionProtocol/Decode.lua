local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Wire = ns.MessageReactionProtocolWire or require("WhisperMessenger.Model.MessageReactionProtocol.Wire")

-- Parses and validates an incoming reaction addon payload: identity,
-- whisper reaction, group reaction, or a long-whisper parts manifest.
local Decode = {}

local MAX_PAYLOAD_BYTES = Wire.MAX_PAYLOAD_BYTES
local VERSION = Wire.VERSION
local isWireId = Wire.IsWireId
local isFingerprint = Wire.IsFingerprint
local isSafeGroupTarget = Wire.IsSafeGroupTarget

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

function Decode.Decode(payload)
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

  if fields[2] == "P" then
    -- MessageParts loads after this module; resolve it at call time.
    local MessageParts = ns.MessageParts or require("WhisperMessenger.Model.MessageParts")
    return MessageParts.DecodeManifest(payload)
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
    if not Wire.IsReactionKey(fields[4]) then
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
  if not Wire.IsReactionKey(fields[4]) then
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

ns.MessageReactionProtocolDecode = Decode
return Decode
