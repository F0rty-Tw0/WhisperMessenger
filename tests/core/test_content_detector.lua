local ContentDetector = require("WhisperMessenger.Core.ContentDetector")

return function()
  -- Returns false when getInstanceInfo is nil
  assert(ContentDetector.IsMythicRestricted(nil) == false, "should return false when getInstanceInfo is nil")

  -- Returns false when getInstanceInfo returns nil difficultyID
  assert(ContentDetector.IsMythicRestricted(function()
    return nil, nil, nil
  end) == false, "should return false when difficultyID is nil")

  -- Returns false for normal dungeon (difficultyID = 1)
  assert(ContentDetector.IsMythicRestricted(function()
    return "Dungeon", "party", 1
  end) == false, "should return false for normal dungeon")

  -- Returns false for heroic raid (difficultyID = 15)
  assert(ContentDetector.IsMythicRestricted(function()
    return "Raid", "raid", 15
  end) == false, "should return false for heroic raid")

  -- Returns true for Mythic Keystone (difficultyID = 8)
  assert(ContentDetector.IsMythicRestricted(function()
    return "Dungeon", "party", 8
  end) == true, "should return true for Mythic Keystone")

  -- Returns false for Mythic Raid (difficultyID = 16) — now encounter-based
  assert(ContentDetector.IsMythicRestricted(function()
    return "Raid", "raid", 16
  end) == false, "should return false for Mythic Raid (encounter-based lock)")

  -- -----------------------------------------------------------------------
  -- IsCompetitiveContent — PvP + arena only. Mythic+ is driven separately
  -- by IsMythicRestricted + MythicSuspendController so the hard lockdown
  -- triggers only when the key is actually started, not on mere presence
  -- at difficulty 8.
  -- -----------------------------------------------------------------------

  -- Returns false when getInstanceInfo is nil
  assert(
    ContentDetector.IsCompetitiveContent(nil) == false,
    "competitive: should return false when getInstanceInfo is nil"
  )

  -- Returns false for open world
  assert(ContentDetector.IsCompetitiveContent(function()
    return "Eastern Kingdoms", "none", 0
  end) == false, "competitive: should return false for open world")

  -- Returns false for normal dungeon
  assert(ContentDetector.IsCompetitiveContent(function()
    return "Dungeon", "party", 1
  end) == false, "competitive: should return false for normal dungeon")

  -- Returns false for heroic raid
  assert(ContentDetector.IsCompetitiveContent(function()
    return "Raid", "raid", 15
  end) == false, "competitive: should return false for heroic raid")

  -- Returns false for Mythic Keystone — Mythic+ uses IsMythicRestricted +
  -- MythicSuspendController (fires only when key is started), not this gate
  assert(ContentDetector.IsCompetitiveContent(function()
    return "Dungeon", "party", 8
  end) == false, "competitive: should return false for Mythic Keystone (handled by IsMythicRestricted)")

  -- Returns false for Mythic Raid — encounter-based, not whole-raid
  assert(ContentDetector.IsCompetitiveContent(function()
    return "Raid", "raid", 16
  end) == false, "competitive: should return false for Mythic Raid")

  -- Returns true for battleground
  assert(ContentDetector.IsCompetitiveContent(function()
    return "Warsong Gulch", "pvp", 1
  end) == true, "competitive: should return true for battleground")

  -- Returns true for arena
  assert(ContentDetector.IsCompetitiveContent(function()
    return "Nagrand Arena", "arena", 1
  end) == true, "competitive: should return true for arena")
end
