local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Wire-format constants, the reaction key set, and the field validators
-- shared by the reaction payload encoder, decoder and chat fallback.
local Wire = {}

local MAX_PAYLOAD_BYTES = 255
local VERSION = "1"

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

function Wire.IsReactionKey(key)
  return reactionKeySet[key] == true
end

function Wire.IsWireId(value)
  return type(value) == "string" and #value > 0 and #value <= 32 and string.match(value, "^[A-Za-z0-9]+$") ~= nil
end

function Wire.IsFingerprint(value)
  return type(value) == "string" and string.match(value, "^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") ~= nil
end

function Wire.IsSafeGroupTarget(value)
  return type(value) == "string" and string.find(value, "|", 1, true) == nil
end

Wire.REACTION_KEYS = REACTION_KEYS
Wire.MAX_PAYLOAD_BYTES = MAX_PAYLOAD_BYTES
Wire.VERSION = VERSION

ns.MessageReactionProtocolWire = Wire
return Wire
