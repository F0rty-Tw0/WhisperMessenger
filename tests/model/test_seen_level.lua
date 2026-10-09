local SeenLevel = require("WhisperMessenger.Model.SeenLevel")

local function sameRealmAmbiguate(name, _context)
  if name == "Firstmoon-MyRealm" then
    return "Firstmoon"
  end
  return name
end

local function throwingAmbiguate()
  error("Ambiguate failed")
end

local function recordSafely(guid, name, level)
  local ok, changed = pcall(SeenLevel.Record, guid, name, level)
  assert(ok, "Record must not raise: " .. tostring(changed))
  return changed
end

return function()
  local savedAmbiguate = _G.Ambiguate
  rawset(_G, "Ambiguate", sameRealmAmbiguate)

  -- test_record_stores_level_by_guid_and_name
  do
    SeenLevel._reset()
    assert(recordSafely("G1", "Firstmoon", 75) == true, "first record should report a change")
    assert(SeenLevel.Get("G1") == 75, "level by guid should be 75")
    assert(SeenLevel.Get(nil, "firstmoon") == 75, "level by name should match case-insensitively")
  end

  -- test_record_same_values_reports_no_change
  do
    assert(recordSafely("G1", "Firstmoon", 75) == false, "same values should report no change")
  end

  -- test_record_new_level_overwrites
  do
    assert(recordSafely("G1", "Firstmoon", 76) == true, "new level should report a change")
    assert(SeenLevel.Get("G1") == 76, "level by guid should be 76")
  end

  -- test_same_realm_name_with_realm_matches_short_name
  do
    assert(SeenLevel.Get(nil, "Firstmoon-MyRealm") == 76, "same-realm full name should find the short-name entry")
  end

  -- test_other_realm_name_is_a_separate_entry
  do
    recordSafely(nil, "Firstmoon-Other", 10)
    assert(SeenLevel.Get(nil, "Firstmoon") == 76, "other-realm record must not overwrite the same-realm entry")
    assert(SeenLevel.Get(nil, "Firstmoon-Other") == 10, "other-realm entry should be 10")
  end

  -- test_invalid_levels_are_ignored
  do
    SeenLevel._reset()
    local invalid = { -1, 0, "75", {} }
    for _, level in ipairs(invalid) do
      assert(recordSafely("G2", "Nobody", level) == false, "invalid level " .. tostring(level) .. " should not record")
    end
    assert(recordSafely("G2", "Nobody", nil) == false, "nil level should not record")
    assert(SeenLevel.Get("G2", "Nobody") == nil, "nothing should be stored for invalid levels")
  end

  -- test_throwing_ambiguate_falls_back_to_lowercased_input
  do
    rawset(_G, "Ambiguate", throwingAmbiguate)
    local ok, key = pcall(SeenLevel.NameKey, "Firstmoon-MyRealm")
    assert(ok, "NameKey must not raise: " .. tostring(key))
    assert(key == "firstmoon-myrealm", "expected lowercased input, got " .. tostring(key))
    assert(SeenLevel.NameKey(nil) == nil, "nil name should have no key")
    rawset(_G, "Ambiguate", sameRealmAmbiguate)
  end

  -- test_cap_wipes_old_entries
  do
    SeenLevel._reset()
    for i = 1, SeenLevel.MAX_ENTRIES + 1 do
      SeenLevel.Record(nil, "n" .. i, 1)
    end
    assert(SeenLevel.Get(nil, "n1") == nil, "oldest entry should be gone after the cap")
  end

  -- test_cap_wipe_keeps_both_entries_of_the_crossing_record
  do
    SeenLevel._reset()
    for i = 1, SeenLevel.MAX_ENTRIES - 1 do
      SeenLevel.Record(nil, "n" .. i, 1)
    end
    SeenLevel.Record("GX", "Newname", 9)
    assert(SeenLevel.Get("GX") == 9, "guid entry of the crossing record should survive the wipe")
    assert(SeenLevel.Get(nil, "Newname") == 9, "name entry of the crossing record should survive the wipe")
    assert(SeenLevel.Get(nil, "n1") == nil, "older entries should be wiped")
  end

  -- test_newer_name_level_beats_stale_guid_level
  do
    SeenLevel._reset()
    recordSafely("G1", "Firstmoon", 70)
    recordSafely(nil, "Firstmoon", 71)
    local level = SeenLevel.Get("G1", "Firstmoon")
    assert(level == 71, "higher name level should win over stale guid level, got " .. tostring(level))
  end

  SeenLevel._reset()
  rawset(_G, "Ambiguate", savedAmbiguate)

  print("  All SeenLevel tests passed")
end
