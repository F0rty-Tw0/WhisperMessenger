local Migrations = require("WhisperMessenger.Persistence.Migrations")
local Schema = require("WhisperMessenger.Persistence.Schema")

return function()
  local db = Schema.NewAccountState()
  assert(db.schemaVersion == 1)
  assert(type(db.conversations) == "table")
  assert(type(db.contacts) == "table")
  assert(type(db.pendingHydration) == "table")

  local migrated = Migrations.Apply(nil, Schema)
  assert(migrated.schemaVersion == Migrations.CURRENT_VERSION)
  assert(type(migrated.conversations) == "table")
  assert(type(migrated.contacts) == "table")
  assert(type(migrated.pendingHydration) == "table")

  local existing = Schema.NewAccountState()
  local existingConversations = existing.conversations
  local existingContacts = existing.contacts
  local existingPendingHydration = existing.pendingHydration
  local migratedExisting = Migrations.Apply(existing, Schema)
  assert(migratedExisting == existing)
  assert(migratedExisting.conversations == existingConversations)
  assert(migratedExisting.contacts == existingContacts)
  assert(migratedExisting.pendingHydration == existingPendingHydration)
  assert(migratedExisting.schemaVersion == Migrations.CURRENT_VERSION)
end
