local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function loadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  local ok, loaded = pcall(require, name)
  if ok then
    return loaded
  end

  error(key .. " module not available")
end

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

  -- Migrate old per-character BNet conversation keys to shared "bnet::" prefix
  local bnetMigrations = {}
  for conversationKey, conversation in pairs(account.conversations or {}) do
    -- Match keys like "profileId::BN::accountId" that aren't already "bnet::BN::..."
    local bnPos = string.find(conversationKey, "::BN::", 1, true)
    if bnPos and string.find(conversationKey, "bnet::", 1, true) ~= 1 then
      local newKey = "bnet" .. string.sub(conversationKey, bnPos)
      bnetMigrations[conversationKey] = { newKey = newKey, conversation = conversation }
    end
  end

  for oldKey, entry in pairs(bnetMigrations) do
    local existing = account.conversations[entry.newKey]
    if existing then
      -- Merge: keep the one with more recent activity
      if (entry.conversation.lastActivityAt or 0) > (existing.lastActivityAt or 0) then
        -- Merge messages from existing into the newer conversation
        for _, msg in ipairs(existing.messages or {}) do
          table.insert(entry.conversation.messages, msg)
        end
        account.conversations[entry.newKey] = entry.conversation
      else
        -- Merge messages from old into the existing conversation
        for _, msg in ipairs(entry.conversation.messages or {}) do
          table.insert(existing.messages, msg)
        end
      end
    else
      account.conversations[entry.newKey] = entry.conversation
    end
    account.conversations[oldKey] = nil
  end

  -- Update active conversation key if it was a BNet key
  if character.activeConversationKey then
    local bnPos = string.find(character.activeConversationKey, "::BN::", 1, true)
    if bnPos and string.find(character.activeConversationKey, "bnet::", 1, true) ~= 1 then
      local newActiveKey = "bnet" .. string.sub(character.activeConversationKey, bnPos)
      if account.conversations[newActiveKey] then
        character.activeConversationKey = newActiveKey
      end
    end
  end

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
