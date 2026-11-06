local SeenGuild = require("WhisperMessenger.Model.SeenGuild")

local NAME = "Arthas-Area52"

local function secretAlways()
  return true
end

-- Real Ambiguate("none") drops only the local realm.
local function ambiguateMyRealm(name)
  return (string.gsub(name, "%-MyRealm$", ""))
end

return function()
  local savedAmbiguate = rawget(_G, "Ambiguate")
  local savedSecret = rawget(_G, "issecretvalue")
  local savedMax = SeenGuild.MAX_ENTRIES

  -- test_never_seen_get_is_nil
  do
    SeenGuild._reset()
    assert(SeenGuild.Get(NAME) == nil, "never seen is nil")
  end

  -- test_record_guild_from_never_seen
  do
    SeenGuild._reset()
    assert(SeenGuild.Record(NAME, "Horde Inc") == true, "guild records")
    assert(SeenGuild.Get(NAME) == "Horde Inc", "guild stored")
  end

  -- test_record_empty_from_never_seen
  do
    SeenGuild._reset()
    assert(SeenGuild.Record(NAME, "") == true, "empty records")
    assert(SeenGuild.Get(NAME) == "", "empty means seen with no guild")
  end

  -- test_guild_replaces_empty
  do
    SeenGuild._reset()
    SeenGuild.Record(NAME, "")
    SeenGuild.Record(NAME, "G")
    assert(SeenGuild.Get(NAME) == "G", "guild replaces empty")
  end

  -- test_empty_clears_guild
  do
    SeenGuild._reset()
    SeenGuild.Record(NAME, "H")
    SeenGuild.Record(NAME, "")
    assert(SeenGuild.Get(NAME) == "", "empty clears guild")
  end

  -- test_new_guild_replaces_old
  do
    SeenGuild._reset()
    SeenGuild.Record(NAME, "H")
    SeenGuild.Record(NAME, "G")
    assert(SeenGuild.Get(NAME) == "G", "new guild replaces old")
  end

  -- test_nil_guild_ignored
  do
    SeenGuild._reset()
    SeenGuild.Record(NAME, "H")
    assert(SeenGuild.Record(NAME, nil) == false, "nil guild is ignored")
    assert(SeenGuild.Record(NAME, 5) == false, "non-string guild is ignored")
    assert(SeenGuild.Get(NAME) == "H", "guild unchanged")
  end

  -- test_nil_name_ignored
  do
    SeenGuild._reset()
    assert(SeenGuild.Record(nil, "G") == false, "nil name is ignored")
  end

  -- test_secret_guild_ignored
  do
    SeenGuild._reset()
    rawset(_G, "issecretvalue", secretAlways)
    local recorded = SeenGuild.Record(NAME, "S")
    rawset(_G, "issecretvalue", savedSecret)
    assert(recorded == false, "secret guild is ignored")
    assert(SeenGuild.Get(NAME) == nil, "secret guild never stored")
  end

  -- test_name_key_normalizes
  do
    SeenGuild._reset()
    rawset(_G, "Ambiguate", ambiguateMyRealm)
    SeenGuild.Record("BOB-MyRealm", "G")
    local short = SeenGuild.Get("bob")
    rawset(_G, "Ambiguate", savedAmbiguate)
    assert(short == "G", "same-realm full name hits the short name, case-insensitive")
  end

  -- test_cap_wipes
  do
    SeenGuild._reset()
    SeenGuild.MAX_ENTRIES = 2
    SeenGuild.Record("One", "A")
    SeenGuild.Record("Two", "B")
    SeenGuild.Record("Three", "C")
    SeenGuild.MAX_ENTRIES = savedMax
    assert(SeenGuild.Get("One") == nil, "oldest entry gone after the cap")
    assert(SeenGuild.Get("Three") == "C", "newest entry survives")
  end

  SeenGuild._reset()
  rawset(_G, "issecretvalue", savedSecret)
  rawset(_G, "Ambiguate", savedAmbiguate)
end
