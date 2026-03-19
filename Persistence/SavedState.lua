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

function SavedState.Initialize(accountState, characterState)
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
