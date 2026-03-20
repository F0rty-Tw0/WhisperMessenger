local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Schema = ns.Schema or require("WhisperMessenger.Persistence.Schema")
local Migrations = ns.Migrations or require("WhisperMessenger.Persistence.Migrations")
local Helpers = ns.PersistenceHelpers or require("WhisperMessenger.Persistence.Helpers")
local LegacyMigration = ns.SavedStateLegacyMigration
  or require("WhisperMessenger.Persistence.SavedState.LegacyMigration")
local PrefixMigration = ns.SavedStatePrefixMigration
  or require("WhisperMessenger.Persistence.SavedState.PrefixMigration")

local SavedState = {}

function SavedState.Initialize(accountState, characterState, localProfileId)
  local account = Migrations.Apply(accountState, Schema)
  local defaults = Schema.NewCharacterState()
  local character = characterState or defaults

  character.window = character.window or defaults.window
  Helpers.applyDefaults(character.window, defaults.window)

  character.icon = character.icon or defaults.icon
  Helpers.applyDefaults(character.icon, defaults.icon)

  LegacyMigration.MigrateCurrentProfile(account, character, localProfileId)
  PrefixMigration.MigratePrefix(account.conversations, "::BN::", "bnet", false, character)
  PrefixMigration.MigratePrefix(account.conversations, "::WOW::", "wow", true, character)

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
