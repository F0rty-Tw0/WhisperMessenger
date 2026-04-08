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

  -- Returns true for Mythic Raid (difficultyID = 16)
  assert(ContentDetector.IsMythicRestricted(function()
    return "Raid", "raid", 16
  end) == true, "should return true for Mythic Raid")
end
