local BNetStatus = require("WhisperMessenger.Model.ContactEnricher.BNetStatus")

local function resolvesShaman()
  return {
    playerInfoByGUID = function()
      return "Shaman", "SHAMAN", "Orc", "Orc"
    end,
  }
end

local function resolvesNothing()
  return {
    playerInfoByGUID = function()
      return nil
    end,
  }
end

local function inWoW(race)
  return { characterName = "Thrall", playerGuid = "Player-1-0001", characterLevel = 80, raceName = race }
end

return function()
  -- alt whose class can't be resolved: race stays with the old class
  do
    local target = { className = "Shaman", classTag = "SHAMAN", raceName = "Orc" }
    BNetStatus.ApplyGameInfoMetadata(target, inWoW("Night Elf"), resolvesNothing())
    assert(target.raceName == "Orc", "race should stay with the stale class, got " .. tostring(target.raceName))
  end

  -- resolved character: race comes from the live game info
  do
    local target = {}
    BNetStatus.ApplyGameInfoMetadata(target, inWoW("Troll"), resolvesShaman())
    assert(target.raceName == "Troll", "expected Troll, got " .. tostring(target.raceName))
  end

  -- resolved character without a game-info race: falls back to the GUID lookup
  do
    local target = {}
    BNetStatus.ApplyGameInfoMetadata(target, inWoW(""), resolvesShaman())
    assert(target.raceName == "Orc", "expected Orc from the GUID lookup, got " .. tostring(target.raceName))
  end

  print("  All BNetStatus race tests passed")
end
