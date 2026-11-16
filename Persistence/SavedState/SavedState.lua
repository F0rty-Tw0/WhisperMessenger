local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Schema = ns.Schema or require("WhisperMessenger.Persistence.Schema")
local Migrations = ns.Migrations or require("WhisperMessenger.Persistence.Migrations")
local Helpers = ns.PersistenceHelpers or require("WhisperMessenger.Persistence.Helpers")
local ConversationMerge = ns.ConversationMerge or require("WhisperMessenger.Model.ConversationMerge")

local SavedState = {}

local LegacyMigration = {}

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

function LegacyMigration.MigrateCurrentProfile(accountState, characterState, localProfileId)
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

local PrefixMigration = {}

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

local CompactRename = {}

-- Copies the saved keys of the old "phone" mode to their compact names, once at load.
-- An existing compact value wins; `false` counts as set. Nothing happens without an old key,
-- so an empty settings table stays empty (fresh-install detection reads it).
function CompactRename.Migrate(account, character)
  local settings = type(account) == "table" and account.settings
  if type(settings) == "table" and settings.phoneLayout ~= nil then
    if settings.compactLayout == nil then
      settings.compactLayout = settings.phoneLayout
    end
    settings.phoneLayout = nil
  end

  if type(character) == "table" and character.phoneWindow ~= nil then
    if type(character.phoneWindow) == "table" and character.compactWindow == nil then
      character.compactWindow = character.phoneWindow
    end
    character.phoneWindow = nil
  end
end

function SavedState.Initialize(accountState, characterState, localProfileId)
  local account = Migrations.Apply(accountState, Schema)
  local defaults = Schema.NewCharacterState()
  local character = characterState or defaults

  character.window = character.window or defaults.window
  Helpers.applyDefaults(character.window, defaults.window)

  character.icon = character.icon or defaults.icon
  Helpers.applyDefaults(character.icon, defaults.icon)

  character.minimapIcon = character.minimapIcon or defaults.minimapIcon
  Helpers.applyDefaults(character.minimapIcon, defaults.minimapIcon)

  LegacyMigration.MigrateCurrentProfile(account, character, localProfileId)
  local maxMessages = (account.settings and account.settings.maxMessagesPerConversation) or 200
  PrefixMigration.MigratePrefix(account.conversations, "::BN::", "bnet", character, maxMessages)
  PrefixMigration.MigratePrefix(account.conversations, "::WOW::", "wow", character, maxMessages)
  CompactRename.Migrate(account, character)

  return account, character
end

SavedState.PrefixMigration = PrefixMigration
SavedState.CompactRename = CompactRename

ns.SavedState = SavedState
return SavedState
