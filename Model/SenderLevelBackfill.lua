local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")

-- Writes levels learned later (a /who reply) onto stored channel and group
-- lines, so their bubbles show "Name (N)" after the fact.
local SenderLevelBackfill = {}

-- Whisper chats keep their level on the conversation, not on each line.
local SKIPPED_CHANNELS = { WOW = true, BN = true }

local function fill(messages, levelsByNameKey)
  local changed = false
  for _, message in ipairs(messages) do
    if message.direction == "in" and message.kind == "user" and type(message.playerName) == "string" then
      local level = levelsByNameKey[SeenLevel.NameKey(message.playerName)]
      -- Levels only rise: a stale reply never lowers a line. A saved value
      -- that is not a number is corrupt and gets replaced.
      local current = message.senderLevel
      if level ~= nil and (type(current) ~= "number" or current < level) then
        message.senderLevel = level
        changed = true
      end
    end
  end
  return changed
end

-- levelsByNameKey: SeenLevel.NameKey -> validated positive level.
-- Returns the set of conversation keys whose lines changed.
function SenderLevelBackfill.Apply(store, levelsByNameKey)
  local changedKeys = {}
  local conversations = store and store.conversations
  if conversations == nil then
    return changedKeys
  end
  for key, conversation in pairs(conversations) do
    if not SKIPPED_CHANNELS[conversation.channel] and type(conversation.messages) == "table" then
      if fill(conversation.messages, levelsByNameKey) then
        changedKeys[key] = true
      end
    end
  end
  return changedKeys
end

ns.SenderLevelBackfill = SenderLevelBackfill

return SenderLevelBackfill
