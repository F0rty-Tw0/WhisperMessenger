local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Migrations = {
  CURRENT_VERSION = 2,
}

function Migrations.Apply(accountState, schema)
  if accountState == nil then
    return schema.NewAccountState()
  end

  if accountState.schemaVersion == nil then
    accountState.schemaVersion = Migrations.CURRENT_VERSION
  end

  if accountState.conversations == nil then
    accountState.conversations = {}
  end

  if accountState.contacts == nil then
    accountState.contacts = {}
  end

  if accountState.pendingHydration == nil then
    accountState.pendingHydration = {}
  end

  -- Strip legacy AFK/DND system messages from saved conversations
  for _, conv in pairs(accountState.conversations) do
    if conv.messages then
      local filtered = {}
      for _, msg in ipairs(conv.messages) do
        if msg.eventName ~= "CHAT_MSG_AFK" and msg.eventName ~= "CHAT_MSG_DND" then
          filtered[#filtered + 1] = msg
        end
      end
      conv.messages = filtered
    end
  end

  accountState.schemaVersion = Migrations.CURRENT_VERSION
  return accountState
end

ns.Migrations = Migrations

return Migrations
