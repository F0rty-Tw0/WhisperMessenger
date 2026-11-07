local CompactRename = require("WhisperMessenger.Persistence.SavedState.CompactRename")

return function()
  -- test_phone_layout_moves_to_compact_layout
  do
    local account = { settings = { phoneLayout = true } }
    CompactRename.Migrate(account, {})
    assert(account.settings.compactLayout == true, "phoneLayout should move to compactLayout")
    assert(account.settings.phoneLayout == nil, "phoneLayout should be removed")
  end

  -- test_false_counts_as_set
  do
    local account = { settings = { phoneLayout = false } }
    CompactRename.Migrate(account, {})
    assert(account.settings.compactLayout == false, "a tester who turned compact off stays off")
    assert(account.settings.phoneLayout == nil, "phoneLayout should be removed")
  end

  -- test_existing_compact_layout_wins
  do
    local account = { settings = { phoneLayout = true, compactLayout = false } }
    CompactRename.Migrate(account, {})
    assert(account.settings.compactLayout == false, "an existing compactLayout should be kept")
    assert(account.settings.phoneLayout == nil, "phoneLayout should be removed")
  end

  -- test_no_old_setting_leaves_settings_untouched
  do
    local account = { settings = {} }
    CompactRename.Migrate(account, {})
    assert(next(account.settings) == nil, "an empty settings table must stay empty so a fresh install stays fresh")
  end

  -- test_phone_window_moves_to_compact_window
  do
    local spot = { x = 10, y = -20, width = 352, phoneLayout = true }
    local character = { phoneWindow = spot }
    CompactRename.Migrate({ settings = {} }, character)
    assert(character.compactWindow == spot, "phoneWindow should be copied as-is")
    assert(character.phoneWindow == nil, "phoneWindow should be removed")
    assert(spot.phoneLayout == true, "the nested field is left alone")
  end

  -- test_existing_compact_window_wins
  do
    local kept = { x = 1 }
    local character = { phoneWindow = { x = 2 }, compactWindow = kept }
    CompactRename.Migrate({ settings = {} }, character)
    assert(character.compactWindow == kept, "an existing compactWindow should be kept")
    assert(character.phoneWindow == nil, "phoneWindow should be removed")
  end

  -- test_no_old_window_leaves_character_untouched
  do
    local character = { window = {} }
    CompactRename.Migrate({ settings = {} }, character)
    assert(character.compactWindow == nil, "no compactWindow should appear without a phoneWindow")
  end

  -- test_non_table_phone_window_is_dropped
  do
    local character = { phoneWindow = 5 }
    CompactRename.Migrate({ settings = {} }, character)
    assert(character.compactWindow == nil, "a corrupt phoneWindow should not be copied")
    assert(character.phoneWindow == nil, "a corrupt phoneWindow should be removed")
  end

  -- test_missing_tables_do_not_error
  do
    assert(pcall(CompactRename.Migrate, nil, nil))
    assert(pcall(CompactRename.Migrate, {}, nil))
    assert(pcall(CompactRename.Migrate, { settings = nil }, {}))
  end
end
