local Migrations = require("WhisperMessenger.Persistence.Migrations")
local Schema = require("WhisperMessenger.Persistence.Schema")

return function()
  -- test_migration_drops_unused_contacts_and_pending_hydration
  do
    local state = {
      schemaVersion = 6,
      conversations = {},
      contacts = { ["arthas-area52"] = { name = "Arthas" } },
      pendingHydration = { "arthas-area52" },
    }
    local migrated = Migrations.Apply(state, Schema)
    assert(migrated == state, "the saved table itself is migrated")
    assert(migrated.contacts == nil, "the unused contacts table is dropped")
    assert(migrated.pendingHydration == nil, "the unused pendingHydration table is dropped")
  end

  -- test_migration_keeps_every_other_account_key
  do
    local conversations = { ["wow::WOW::arthas-area52"] = { channel = "WOW", messages = {} } }
    local channelMessages = { entries = {}, nextSequence = 3 }
    local settings = { showPlayerLevels = true }
    local filters = { ignored = {}, rules = {} }
    local sharedWindow = { x = 12, y = 34 }
    local state = {
      schemaVersion = 6,
      conversations = conversations,
      channelMessages = channelMessages,
      settings = settings,
      filters = filters,
      sharedWindow = sharedWindow,
      contacts = {},
      pendingHydration = {},
    }
    local migrated = Migrations.Apply(state, Schema)
    assert(migrated.conversations == conversations, "conversations stay")
    assert(migrated.channelMessages == channelMessages, "channel messages stay")
    assert(migrated.settings == settings and settings.showPlayerLevels == true, "settings stay")
    assert(migrated.filters == filters, "filters stay")
    assert(migrated.sharedWindow == sharedWindow and sharedWindow.x == 12, "the shared window spot stays")
  end

  -- test_save_without_the_unused_keys_migrates
  do
    local ok, migrated = pcall(Migrations.Apply, { conversations = {} }, Schema)
    assert(ok, "a save that never had the keys migrates: " .. tostring(migrated))
    assert(migrated.contacts == nil, "contacts stays absent")
    assert(migrated.pendingHydration == nil, "pendingHydration stays absent")
  end

  -- test_new_account_starts_without_the_unused_keys
  do
    local migrated = Migrations.Apply(nil, Schema)
    assert(migrated.contacts == nil, "a new account has no contacts table")
    assert(migrated.pendingHydration == nil, "a new account has no pendingHydration table")
  end

  -- test_migrating_twice_changes_nothing_more
  do
    local state = { conversations = {}, contacts = {}, pendingHydration = {}, settings = { showPlayerLevels = true } }
    local once = Migrations.Apply(state, Schema)
    local conversations = once.conversations
    local twice = Migrations.Apply(once, Schema)
    assert(twice == state, "the same table comes back")
    assert(twice.contacts == nil and twice.pendingHydration == nil, "the keys stay dropped")
    assert(twice.conversations == conversations, "conversations stay on the second run")
    assert(twice.settings.showPlayerLevels == true, "settings stay on the second run")
  end
end
