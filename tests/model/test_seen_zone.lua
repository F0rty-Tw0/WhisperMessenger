local SeenZone = require("WhisperMessenger.Model.SeenZone")

local function secretAlways()
  return true
end

local function throwingSecretCheck()
  error("issecretvalue failed")
end

-- Real Ambiguate("none") drops only the local realm.
local function ambiguateMyRealm(name)
  return (string.gsub(name, "%-MyRealm$", ""))
end

return function()
  local savedAmbiguate = rawget(_G, "Ambiguate")
  local savedSecret = _G.issecretvalue
  local savedMax = SeenZone.MAX_ENTRIES

  -- test_record_stores_zone_and_seen_at
  do
    SeenZone._reset()
    assert(SeenZone.Record("Bob", "Stormwind", 100) == true, "first record should succeed")
    local zone, seenAt = SeenZone.Get("Bob")
    assert(zone == "Stormwind", "zone should be Stormwind, got " .. tostring(zone))
    assert(seenAt == 100, "seenAt should be 100, got " .. tostring(seenAt))
  end

  -- test_record_same_zone_refreshes_seen_at
  do
    SeenZone._reset()
    SeenZone.Record("Bob", "Stormwind", 100)
    assert(SeenZone.Record("Bob", "Stormwind", 200) == true, "same zone again should succeed")
    local _zone, seenAt = SeenZone.Get("Bob")
    assert(seenAt == 200, "seenAt should refresh to 200, got " .. tostring(seenAt))
  end

  -- test_record_new_zone_replaces_old
  do
    SeenZone._reset()
    SeenZone.Record("Bob", "Stormwind", 100)
    SeenZone.Record("Bob", "Ironforge", 300)
    local zone, seenAt = SeenZone.Get("Bob")
    assert(zone == "Ironforge" and seenAt == 300, "new zone should replace the old entry")
  end

  -- test_invalid_zone_is_ignored
  do
    SeenZone._reset()
    assert(SeenZone.Record("Bob", "", 1) == false, "empty zone should not record")
    assert(SeenZone.Record("Bob", nil, 1) == false, "nil zone should not record")
    assert(SeenZone.Record("Bob", 5, 1) == false, "non-string zone should not record")
    assert(SeenZone.Get("Bob") == nil, "nothing should be stored for invalid zones")
  end

  -- test_nil_name_is_ignored
  do
    assert(SeenZone.Record(nil, "X", 1) == false, "nil name should not record")
  end

  -- test_secret_zone_is_ignored
  do
    rawset(_G, "issecretvalue", secretAlways)
    assert(SeenZone.Record("Bob", "Stormwind", 1) == false, "secret zone should not record")
    rawset(_G, "issecretvalue", throwingSecretCheck)
    assert(SeenZone.Record("Bob", "Stormwind", 1) == false, "throwing secret check should not record")
    rawset(_G, "issecretvalue", savedSecret)
    assert(SeenZone.Get("Bob") == nil, "nothing should be stored for secret zones")
  end

  -- test_name_lookup_is_case_insensitive
  do
    SeenZone._reset()
    SeenZone.Record("BOB", "Stormwind", 1)
    assert(SeenZone.Get("bob") == "Stormwind", "lookup should be case-insensitive")
  end

  -- test_same_realm_name_matches_short_name
  do
    SeenZone._reset()
    rawset(_G, "Ambiguate", ambiguateMyRealm)
    SeenZone.Record("Bob-MyRealm", "Stormwind", 1)
    local zone = SeenZone.Get("Bob")
    rawset(_G, "Ambiguate", savedAmbiguate)
    assert(zone == "Stormwind", "same-realm full name should hit the short name, got " .. tostring(zone))
  end

  -- test_other_realm_name_stays_separate_from_short_name
  do
    SeenZone._reset()
    rawset(_G, "Ambiguate", ambiguateMyRealm)
    SeenZone.Record("Bob-OtherRealm", "Orgrimmar", 2)
    local full = SeenZone.Get("Bob-OtherRealm")
    local short = SeenZone.Get("Bob")
    rawset(_G, "Ambiguate", savedAmbiguate)
    assert(full == "Orgrimmar", "other-realm full name should hit, got " .. tostring(full))
    assert(short == nil, "other-realm player must not match the bare name, got " .. tostring(short))
  end

  -- test_cap_wipes_old_entries
  do
    SeenZone._reset()
    SeenZone.MAX_ENTRIES = 2
    SeenZone.Record("One", "A", 1)
    SeenZone.Record("Two", "B", 2)
    SeenZone.Record("Three", "C", 3)
    SeenZone.MAX_ENTRIES = savedMax
    assert(SeenZone.Get("One") == nil, "oldest entry should be gone after the cap")
    assert(SeenZone.Get("Three") == "C", "newest entry should survive the wipe")
  end

  SeenZone._reset()
  rawset(_G, "issecretvalue", savedSecret)
  rawset(_G, "Ambiguate", savedAmbiguate)

  print("  All SeenZone tests passed")
end
