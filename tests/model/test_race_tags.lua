local RaceTags = require("WhisperMessenger.Model.Identity.RaceTags")

-- Ids with gaps, like the game's race list: nil between real races.
local RACES = {
  [1] = { raceName = "Human", clientFileString = "Human" },
  [5] = { raceName = "Undead", clientFileString = "Scourge" },
  [24] = { raceName = "Pandaren", clientFileString = "Pandaren" },
  [100] = { raceName = "Lastrace", clientFileString = "LastTag" },
}

local function install(races, calls)
  rawset(_G, "C_CreatureInfo", {
    GetRaceInfo = function(id)
      calls[#calls + 1] = id
      return races[id]
    end,
  })
  RaceTags._reset()
end

return function()
  local saved = rawget(_G, "C_CreatureInfo")

  -- test_maps_race_name_to_race_tag
  do
    install(RACES, {})
    assert(RaceTags.FromName("Undead") == "Scourge", "Undead should map to Scourge")
  end

  -- test_scan_skips_nil_ids_up_to_100
  do
    install(RACES, {})
    assert(RaceTags.FromName("Pandaren") == "Pandaren", "a race after a nil id should still map")
    assert(RaceTags.FromName("Lastrace") == "LastTag", "id 100 should be scanned")
  end

  -- test_unknown_name_returns_nil
  do
    install(RACES, {})
    assert(RaceTags.FromName("Dryad") == nil, "an unknown race name has no tag")
    assert(RaceTags.FromName(nil) == nil, "nil race name has no tag")
  end

  -- test_list_built_once
  do
    local calls = {}
    install(RACES, calls)
    RaceTags.FromName("Human")
    RaceTags.FromName("Undead")
    assert(#calls == 100, "race list should be read once, got " .. #calls .. " calls")
  end

  -- test_missing_api_returns_nil
  do
    rawset(_G, "C_CreatureInfo", nil)
    RaceTags._reset()
    assert(RaceTags.FromName("Human") == nil, "no race API means no tag")
  end

  -- test_throwing_id_skipped
  do
    rawset(_G, "C_CreatureInfo", {
      GetRaceInfo = function(id)
        if id == 2 then
          error("bad id")
        end
        return RACES[id]
      end,
    })
    RaceTags._reset()
    assert(RaceTags.FromName("Undead") == "Scourge", "a throwing id must not stop the scan")
  end

  rawset(_G, "C_CreatureInfo", saved)
  RaceTags._reset()
end
