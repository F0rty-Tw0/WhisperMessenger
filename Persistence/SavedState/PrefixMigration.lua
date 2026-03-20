local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PrefixMigration = {}

local function updateActiveConversationKey(characterState, conversations, matchPattern, newPrefix, guardPrefix)
  if characterState.activeConversationKey then
    local pos = string.find(characterState.activeConversationKey, matchPattern, 1, true)
    if pos and string.find(characterState.activeConversationKey, guardPrefix, 1, true) ~= 1 then
      local newActiveKey = newPrefix .. string.sub(characterState.activeConversationKey, pos)
      if conversations[newActiveKey] then
        characterState.activeConversationKey = newActiveKey
      end
    end
  end
end

function PrefixMigration.MigratePrefix(conversations, matchPattern, newPrefix, sortMessages, characterState)
  local migrations = {}
  for conversationKey, conversation in pairs(conversations or {}) do
    local pos = string.find(conversationKey, matchPattern, 1, true)
    if pos and string.find(conversationKey, newPrefix .. "::", 1, true) ~= 1 then
      local newKey = newPrefix .. string.sub(conversationKey, pos)
      migrations[conversationKey] = { newKey = newKey, conversation = conversation }
    end
  end

  for oldKey, entry in pairs(migrations) do
    local existing = conversations[entry.newKey]
    if existing then
      -- Merge: keep the one with more recent activity, combine messages
      if (entry.conversation.lastActivityAt or 0) > (existing.lastActivityAt or 0) then
        for _, msg in ipairs(existing.messages or {}) do
          table.insert(entry.conversation.messages, msg)
        end
        if sortMessages then
          table.sort(entry.conversation.messages, function(a, b)
            return (a.sentAt or 0) < (b.sentAt or 0)
          end)
        end
        conversations[entry.newKey] = entry.conversation
      else
        for _, msg in ipairs(entry.conversation.messages or {}) do
          table.insert(existing.messages, msg)
        end
        if sortMessages then
          table.sort(existing.messages, function(a, b)
            return (a.sentAt or 0) < (b.sentAt or 0)
          end)
        end
      end
    else
      conversations[entry.newKey] = entry.conversation
    end
    conversations[oldKey] = nil
  end

  updateActiveConversationKey(characterState, conversations, matchPattern, newPrefix, newPrefix .. "::")
end

ns.SavedStatePrefixMigration = PrefixMigration
return PrefixMigration
