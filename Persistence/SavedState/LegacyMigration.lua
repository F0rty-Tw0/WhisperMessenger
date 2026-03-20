local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

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

ns.SavedStateLegacyMigration = LegacyMigration
return LegacyMigration
