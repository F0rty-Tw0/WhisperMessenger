local ProfileCharacter = require("WhisperMessenger.Model.ProfileCharacter")

-- A Battle.net friend's character is read live from Battle.net when the menu
-- opens: only while they play this game version in this region. A stored
-- character may be one they logged off hours ago, or on another version.

local OWN = { display = "Argent Dawn", normalized = "ArgentDawn" }
local GAME = { regionId = 3, projectId = 1 }

local function liveGame(overrides)
  local game = {
    isOnline = true,
    clientProgram = "WoW",
    wowProjectID = 1,
    regionID = 3,
    characterName = "Thrall",
    realmName = "Area 52",
  }
  for key, value in pairs(overrides or {}) do
    game[key] = value
  end
  return game
end

return function()
  local savedBattleNet = _G.C_BattleNet
  local savedIsSecret = _G.issecretvalue
  local accountInfo
  rawset(_G, "C_BattleNet", {
    GetAccountInfoByID = function(id)
      return id == 7 and accountInfo or nil
    end,
  })
  local friend = { channel = "BN", displayName = "Friend#1234", battleTag = "Friend#1234", bnetAccountID = 7, gameAccountName = "Garrosh-Kazzak" }

  local function characterWith(gameInfo)
    accountInfo = { bnetAccountID = 7, battleTag = "Friend#1234", isOnline = true, gameAccountInfo = gameInfo }
    return ProfileCharacter.FromItem(friend, OWN, GAME)
  end

  -- test_friend_in_same_game_uses_live_character
  do
    local character = characterWith(liveGame())
    assert(character ~= nil and character.name == "Thrall", "live character used, got " .. tostring(character and character.name))
    assert(character.displayRealm == "Area 52", "Battle.net gives the realm's display name")
  end

  -- test_friend_on_another_game_version_has_none
  do
    assert(characterWith(liveGame({ wowProjectID = 2 })) == nil, "a Classic character has no Retail profile")
  end

  -- test_friend_in_another_region_has_none
  do
    assert(characterWith(liveGame({ regionID = 1 })) == nil, "a US character is not on EU sites")
  end

  -- test_friend_logged_off_has_none
  do
    assert(characterWith(liveGame({ isOnline = false })) == nil, "the last character of an offline friend is stale")
  end

  -- test_friend_in_another_blizzard_game_has_none
  do
    assert(characterWith(liveGame({ clientProgram = "WTCG" })) == nil, "Hearthstone is not WoW")
  end

  -- test_stored_character_is_not_used
  do
    accountInfo = nil
    assert(ProfileCharacter.FromItem(friend, OWN, GAME) == nil, "no live info, no character, even with one stored")
  end

  -- test_secret_live_character_has_none
  do
    local secret = "Secret"
    rawset(_G, "issecretvalue", function(value)
      return value == secret
    end)
    local character = characterWith(liveGame({ characterName = secret }))
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(character == nil, "a secret character name is never read")
  end

  -- test_secret_online_flag_has_none
  do
    -- isOnline is the only `true` in the live info, so it alone is secret.
    rawset(_G, "issecretvalue", function(value)
      return value == true
    end)
    local character = characterWith(liveGame())
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(character == nil, "a secret online flag is never compared")
  end

  rawset(_G, "C_BattleNet", savedBattleNet)
end
