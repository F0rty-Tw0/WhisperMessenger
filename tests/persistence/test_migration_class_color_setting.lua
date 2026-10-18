local Migrations = require("WhisperMessenger.Persistence.Migrations")
local Schema = require("WhisperMessenger.Persistence.Schema")

return function()
  -- test_saved_class_colour_choice_is_removed
  do
    local state = { settings = { classColorSenderNames = false, showPlayerLevels = true } }
    local migrated = Migrations.Apply(state, Schema)
    assert(migrated.settings.classColorSenderNames == nil, "the class colour choice is removed")
    assert(migrated.settings.showPlayerLevels == true, "other settings stay")
  end

  -- test_save_without_settings_migrates
  do
    local ok, err = pcall(Migrations.Apply, {}, Schema)
    assert(ok, "a save without settings migrates: " .. tostring(err))
  end

  -- test_save_without_the_key_stays_the_same
  do
    local migrated = Migrations.Apply({ settings = { showPlayerLevels = true } }, Schema)
    assert(migrated.settings.classColorSenderNames == nil, "the key stays absent")
    assert(migrated.settings.showPlayerLevels == true, "other settings stay")
  end
end
