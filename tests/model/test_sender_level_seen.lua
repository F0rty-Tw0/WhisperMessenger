local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local SenderLevel = require("WhisperMessenger.Model.SenderLevel")

local GUID = "Player-1-0001"
local STUBBED = { "UnitTokenFromGUID", "UnitLevel", "UnitGUID", "IsInRaid", "GetNumGroupMembers", "C_BattleNet", "Ambiguate" }

local function lookupSafely(guid, name)
  local ok, level = pcall(SenderLevel.Lookup, guid, name)
  assert(ok, "Lookup must not raise: " .. tostring(level))
  return level
end

return function()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = _G[name]
  end
  local function reset()
    for _, name in ipairs(STUBBED) do
      _G[name] = nil
    end
    PresenceCache._reset()
    SeenLevel._reset()
  end

  -- test_seen_level_by_guid_when_no_other_source
  do
    reset()
    SeenLevel.Record(GUID, nil, 8)
    assert(lookupSafely(GUID) == 8, "seen level by guid should be 8")
  end

  -- test_seen_level_by_name_when_guid_unknown
  do
    reset()
    SeenLevel.Record(nil, "Diaperspin", 8)
    assert(lookupSafely("Player-9-0009", "Diaperspin") == 8, "seen level by name should be 8")
  end

  -- test_live_unit_level_wins_over_seen_level
  do
    reset()
    SeenLevel.Record(GUID, nil, 8)
    rawset(_G, "UnitTokenFromGUID", function(guid)
      if guid == GUID then
        return "target"
      end
      return nil
    end)
    rawset(_G, "UnitLevel", function(unit)
      if unit == "target" then
        return 20
      end
      return nil
    end)
    assert(lookupSafely(GUID) == 20, "live unit level should win over the seen level")
  end

  -- test_nil_guid_has_no_level_even_when_name_seen
  do
    reset()
    SeenLevel.Record(nil, "Diaperspin", 8)
    assert(lookupSafely(nil, "Diaperspin") == nil, "nil guid should have no level")
  end

  reset()
  for _, name in ipairs(STUBBED) do
    _G[name] = saved[name]
  end

  print("  All SenderLevel seen-level tests passed")
end
