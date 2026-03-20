local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule

local Schema = loadModule("WhisperMessenger.Persistence.Schema", "Schema")
local Migrations = loadModule("WhisperMessenger.Persistence.Migrations", "Migrations")

local SavedState = {}

local LEGACY_PROFILE_PREFIX = "current::"

local function rewriteLegacyConversationKey(conversationKey, localProfileId)
  if type(conversationKey) ~= "string" or type(localProfileId) ~= "string" then
    return conversationKey
  end

  if string.find(conversationKey, LEGACY_PROFILE_PREFIX, 1, true) ~= 1 then
    return conversationKey
  end

  return localProfileId .. string.sub(conversationKey, string.len("current") + 1)
end

local function hasProfileConversations(accountState, localProfileId)
  local prefix = (localProfileId or "") .. "::"
  for conversationKey in pairs(accountState.conversations or {}) do
    if string.find(conversationKey, prefix, 1, true) == 1 then
      return true
    end
  end

  return false
end

local function migrateLegacyCurrentProfile(accountState, characterState, localProfileId)
  if type(localProfileId) ~= "string" or localProfileId == "" then
    return
  end

  if hasProfileConversations(accountState, localProfileId) then
    local migratedActiveKey = rewriteLegacyConversationKey(characterState.activeConversationKey, localProfileId)
    if migratedActiveKey ~= characterState.activeConversationKey and accountState.conversations[migratedActiveKey] ~= nil then
      characterState.activeConversationKey = migratedActiveKey
    end
    return
  end

  local migratedKeys = {}
  for conversationKey, conversation in pairs(accountState.conversations or {}) do
    if string.find(conversationKey, LEGACY_PROFILE_PREFIX, 1, true) == 1 then
      local migratedKey = rewriteLegacyConversationKey(conversationKey, localProfileId)
      if accountState.conversations[migratedKey] == nil then
        accountState.conversations[migratedKey] = conversation
      end
      migratedKeys[conversationKey] = migratedKey
    end
  end

  for conversationKey in pairs(migratedKeys) do
    accountState.conversations[conversationKey] = nil
  end

  local migratedActiveKey = rewriteLegacyConversationKey(characterState.activeConversationKey, localProfileId)
  if migratedActiveKey ~= characterState.activeConversationKey and accountState.conversations[migratedActiveKey] ~= nil then
    characterState.activeConversationKey = migratedActiveKey
  end
end

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

local function migrateConversationPrefix(conversations, matchPattern, newPrefix, sortMessages, characterState)
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

function SavedState.Initialize(accountState, characterState, localProfileId)
  local account = Migrations.Apply(accountState, Schema)
  local defaults = Schema.NewCharacterState()
  local character = characterState or defaults

  character.window = character.window or defaults.window
  if character.window.anchorPoint == nil then
    character.window.anchorPoint = defaults.window.anchorPoint
  end
  if character.window.relativePoint == nil then
    character.window.relativePoint = defaults.window.relativePoint
  end
  if character.window.x == nil then
    character.window.x = defaults.window.x
  end
  if character.window.y == nil then
    character.window.y = defaults.window.y
  end
  if character.window.width == nil then
    character.window.width = defaults.window.width
  end
  if character.window.height == nil then
    character.window.height = defaults.window.height
  end

  character.icon = character.icon or defaults.icon
  if character.icon.anchorPoint == nil then
    character.icon.anchorPoint = defaults.icon.anchorPoint
  end
  if character.icon.relativePoint == nil then
    character.icon.relativePoint = defaults.icon.relativePoint
  end
  if character.icon.x == nil then
    character.icon.x = defaults.icon.x
  end
  if character.icon.y == nil then
    character.icon.y = defaults.icon.y
  end

  migrateLegacyCurrentProfile(account, character, localProfileId)

  migrateConversationPrefix(account.conversations, "::BN::", "bnet", false, character)
  migrateConversationPrefix(account.conversations, "::WOW::", "wow", true, character)

  return account, character
end

function SavedState.ListProfileConversations(accountState, localProfileId)
  local prefix = (localProfileId or "") .. "::"
  local filtered = {}

  for conversationKey, conversation in pairs(accountState.conversations or {}) do
    if string.find(conversationKey, prefix, 1, true) == 1 then
      filtered[conversationKey] = conversation
    end
  end

  return filtered
end

ns.SavedState = SavedState

return SavedState
