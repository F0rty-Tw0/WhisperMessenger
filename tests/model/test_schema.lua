local Migrations = require("WhisperMessenger.Persistence.Migrations")
local Schema = require("WhisperMessenger.Persistence.Schema")

return function()
  local db = Schema.NewAccountState()
  assert(db.schemaVersion == 1)
  assert(type(db.conversations) == "table")
  assert(db.contacts == nil and db.pendingHydration == nil, "new accounts carry no unused tables")
  assert(type(db.channelMessages) == "table")
  assert(type(db.filters) == "table" and type(db.filters.ignored) == "table", "new accounts start with an ignore list")
  assert(type(db.filters.rules) == "table" and next(db.filters.rules) == nil, "new accounts start with no keyword rules")

  local migrated = Migrations.Apply(nil, Schema)
  assert(migrated.schemaVersion == Migrations.CURRENT_VERSION)
  assert(type(migrated.conversations) == "table")
  assert(type(migrated.channelMessages) == "table")

  local existing = Schema.NewAccountState()
  local existingConversations = existing.conversations
  local existingChannelMessages = existing.channelMessages
  local migratedExisting = Migrations.Apply(existing, Schema)
  assert(migratedExisting == existing)
  assert(migratedExisting.conversations == existingConversations)
  assert(migratedExisting.channelMessages == existingChannelMessages)
  assert(migratedExisting.schemaVersion == Migrations.CURRENT_VERSION)
end
