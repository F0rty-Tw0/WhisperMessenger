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

local function inWoW(level)
  return { characterName = "Thrall", playerGuid = "Player-1-0001", characterLevel = level }
end

return function()
  -- level copied together with the class when the friend is in WoW
  do
    local target = {}
    BNetStatus.ApplyGameInfoMetadata(target, inWoW(80), resolvesShaman())
    assert(target.characterLevel == 80, "expected level 80, got " .. tostring(target.characterLevel))
  end

  -- not in WoW: level left alone
  do
    local target = { characterLevel = 70 }
    BNetStatus.ApplyGameInfoMetadata(target, { characterName = "", characterLevel = 80 }, resolvesShaman())
    assert(target.characterLevel == 70, "level must not change while not in WoW")
  end

  -- zero or missing level keeps the old value
  do
    local target = { characterLevel = 70 }
    BNetStatus.ApplyGameInfoMetadata(target, inWoW(0), resolvesShaman())
    assert(target.characterLevel == 70, "level 0 should be ignored")
    BNetStatus.ApplyGameInfoMetadata(target, inWoW(nil), resolvesShaman())
    assert(target.characterLevel == 70, "missing level should be ignored")
  end

  -- alt whose class can't be resolved yet: class and level both stay
  do
    local target = { className = "Shaman", classTag = "SHAMAN", characterLevel = 80 }
    BNetStatus.ApplyGameInfoMetadata(target, inWoW(12), resolvesNothing())
    assert(target.className == "Shaman", "class should stay when unresolved")
    assert(target.characterLevel == 80, "level should stay with the stale class, got " .. tostring(target.characterLevel))
  end

  print("  All BNetStatus level tests passed")
end
