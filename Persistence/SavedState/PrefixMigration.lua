local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PrefixMigration = {}

local ConversationMerge = ns.ConversationMerge or require("WhisperMessenger.Model.ConversationMerge")

local function updateActiveConversationKey(characterState, mappings)
  if characterState and characterState.activeConversationKey then
    characterState.activeConversationKey = mappings[characterState.activeConversationKey] or characterState.activeConversationKey
  end
end

function PrefixMigration.MigratePrefix(conversations, matchPattern, newPrefix, characterState, maxMessages)
  local migrations = {}
  for conversationKey in pairs(conversations or {}) do
    local pos = string.find(conversationKey, matchPattern, 1, true)
    if pos and string.find(conversationKey, newPrefix .. "::", 1, true) ~= 1 then
      migrations[conversationKey] = newPrefix .. string.sub(conversationKey, pos)
    end
  end

  local mappings = {}
  for oldKey, newKey in pairs(migrations) do
    local rekeyed = ConversationMerge.Rekey(conversations, oldKey, newKey, maxMessages)
    for sourceKey, destinationKey in pairs(rekeyed) do
      mappings[sourceKey] = destinationKey
    end
  end

  updateActiveConversationKey(characterState, mappings)
  return mappings
end

ns.SavedStatePrefixMigration = PrefixMigration
return PrefixMigration
