local ScanSignature = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ScanSignature")

local KEY = "bnet::friend"

-- What BNetResolver.ResolveAccountInfo answers for the conversation's friend.
local function friend()
  return {
    battleTag = "Friend#1234",
    isOnline = true,
    isAFK = false,
    isDND = false,
    lastOnlineTime = 1000,
    gameAccountInfo = {
      isOnline = true,
      isGameAFK = false,
      isGameBusy = false,
      clientProgram = "WoW",
      characterName = "Jaina",
      realmName = "Area52",
      realmDisplayName = "Area 52",
      className = "Mage",
      raceName = "Human",
      characterLevel = 80,
      areaName = "Dornogal",
      factionName = "Alliance",
      playerGuid = "Player-1-0001",
    },
  }
end

-- Every live field the open window reads, each with a value that differs
-- from friend() above. game = true: the field sits on gameAccountInfo.
local SHOWN_FIELDS = {
  { field = "isOnline", value = false },
  { field = "isAFK", value = true },
  { field = "isDND", value = true },
  { field = "lastOnlineTime", value = 2000 },
  { game = true, field = "isOnline", value = false },
  { game = true, field = "isGameAFK", value = true },
  { game = true, field = "isGameBusy", value = true },
  { game = true, field = "clientProgram", value = "App" },
  { game = true, field = "characterName", value = "Thrall" },
  { game = true, field = "realmName", value = "Stormrage" },
  { game = true, field = "realmDisplayName", value = "Storm Rage" },
  { game = true, field = "className", value = "Shaman" },
  { game = true, field = "raceName", value = "Orc" },
  { game = true, field = "characterLevel", value = 81 },
  { game = true, field = "areaName", value = "Isle of Dorn" },
  { game = true, field = "factionName", value = "Horde" },
  { game = true, field = "playerGuid", value = "Player-1-0002" },
}

local function fieldOwner(accountInfo, change)
  return change.game and accountInfo.gameAccountInfo or accountInfo
end

return function()
  -- test_first_scan_of_a_friend_reports_a_change
  do
    assert(ScanSignature.Update({}, KEY, friend()) == true, "a friend with no earlier signature counts as changed")
  end

  -- test_identical_scan_reports_no_change
  do
    local signatures = {}
    ScanSignature.Update(signatures, KEY, friend())

    assert(ScanSignature.Update(signatures, KEY, friend()) == false, "the same live state is not a change")
  end

  -- test_each_field_the_window_shows_reports_a_change
  for _, change in ipairs(SHOWN_FIELDS) do
    local label = (change.game and "gameAccountInfo." or "accountInfo.") .. change.field
    local signatures = {}
    ScanSignature.Update(signatures, KEY, friend())
    local changed = friend()
    fieldOwner(changed, change)[change.field] = change.value

    assert(ScanSignature.Update(signatures, KEY, changed) == true, label .. " changing must count as a change")
    assert(ScanSignature.Update(signatures, KEY, changed) == false, label .. ": the new value is remembered")

    local cleared = friend()
    fieldOwner(cleared, change)[change.field] = nil
    assert(ScanSignature.Update(signatures, KEY, cleared) == true, label .. " going missing must count as a change")
  end

  -- test_field_the_window_does_not_show_reports_no_change
  do
    local signatures = {}
    ScanSignature.Update(signatures, KEY, friend())
    local changed = friend()
    changed.customMessage = "brb"
    changed.gameAccountInfo.richPresence = "Dornogal - Area 52"

    assert(ScanSignature.Update(signatures, KEY, changed) == false, "a broadcast or rich presence text is not on screen")
  end

  -- test_friend_without_game_account_info_compares_as_missing
  -- Classic flavors can hand back an account with no gameAccountInfo.
  do
    local signatures = {}
    local bare = friend()
    bare.gameAccountInfo = nil
    ScanSignature.Update(signatures, KEY, bare)

    assert(ScanSignature.Update(signatures, KEY, bare) == false, "a missing game account stays unchanged")
    assert(ScanSignature.Update(signatures, KEY, friend()) == true, "a game account appearing is a change")
    assert(ScanSignature.Update(signatures, KEY, {}) == true, "every field going missing is a change")
    assert(ScanSignature.Update(signatures, KEY, {}) == false, "and stays unchanged after that")
  end

  -- test_friend_that_no_longer_resolves_reports_one_change
  do
    local signatures = {}
    ScanSignature.Update(signatures, KEY, friend())

    assert(ScanSignature.Update(signatures, KEY, nil) == true, "a friend that no longer resolves is a change")
    assert(ScanSignature.Update(signatures, KEY, nil) == false, "a conversation with no friend stays unchanged")
    assert(ScanSignature.Update(signatures, KEY, friend()) == true, "the friend coming back is a change")
  end

  -- test_signatures_are_kept_per_conversation
  do
    local signatures = {}
    ScanSignature.Update(signatures, KEY, friend())

    assert(ScanSignature.Update(signatures, "bnet::other", friend()) == true, "another conversation has its own signature")
    assert(ScanSignature.Update(signatures, KEY, friend()) == false, "and leaves the first one alone")
  end

  -- test_secret_values_are_compared_without_reading_them
  -- 12.0 hands out secret values that raise on comparison, a new one per
  -- call, so they are told apart from plain values only.
  do
    local savedIsSecret = rawget(_G, "issecretvalue")
    local secrets = {}
    rawset(_G, "issecretvalue", function(value)
      return secrets[value] == true
    end)
    local function secretFriend()
      local accountInfo = friend()
      local secret = {}
      secrets[secret] = true
      accountInfo.gameAccountInfo.areaName = secret
      return accountInfo
    end
    local signatures = {}
    ScanSignature.Update(signatures, KEY, friend())

    assert(ScanSignature.Update(signatures, KEY, secretFriend()) == true, "a value turning secret is a change")
    assert(ScanSignature.Update(signatures, KEY, secretFriend()) == false, "two secret values count as the same")
    assert(ScanSignature.Update(signatures, KEY, friend()) == true, "a secret value turning readable is a change")

    rawset(_G, "issecretvalue", savedIsSecret)
  end

  -- test_prune_drops_signatures_of_conversations_that_are_gone
  -- Covers a deleted conversation and the old key of a rekeyed one.
  do
    local signatures = {}
    ScanSignature.Update(signatures, "bnet::kept", friend())
    ScanSignature.Update(signatures, "bnet::deleted", friend())
    ScanSignature.Update(signatures, "bnet::old-key", friend())

    ScanSignature.Prune(signatures, { ["bnet::kept"] = {}, ["bnet::new-key"] = {} })

    assert(ScanSignature.Update(signatures, "bnet::kept", friend()) == false, "a live conversation keeps its signature")
    assert(ScanSignature.Update(signatures, "bnet::deleted", friend()) == true, "a deleted conversation's signature is gone")
    assert(ScanSignature.Update(signatures, "bnet::old-key", friend()) == true, "a rekeyed conversation's old signature is gone")
  end
end
