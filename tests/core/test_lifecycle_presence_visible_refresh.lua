-- A Battle.net friend scan while the messenger is open rebuilds the window
-- only when the scan changed something the window shows for a friend the
-- player has a conversation with.

local FakeScanResolver = require("tests.helpers.fake_scan_resolver")
local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local Identity = require("WhisperMessenger.Model.Identity")

local FRIEND_KEY = "bnet::friend"
local STRANGER_KEY = "bnet::stranger"
local WHISPER_KEY = "wow::WOW::arthas-area52"

local function makeDeps(friendMap)
  return {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetResolver", 1, true) then
        return FakeScanResolver.New(function()
          return friendMap
        end)
      end
      return require(modulePath)
    end,
  }
end

local function gameInfo(characterName)
  return {
    isOnline = true,
    clientProgram = "WoW",
    characterName = characterName,
    realmName = "Area52",
    className = "Mage",
    characterLevel = 80,
    areaName = "Dornogal",
  }
end

-- Friend#1234 has a conversation; Other#5678 is a friend with none.
local function friendMap()
  return {
    ["Friend#1234"] = { bnetAccountID = 42, accountInfo = { battleTag = "Friend#1234", gameAccountInfo = gameInfo("Jaina") } },
    ["Other#5678"] = { bnetAccountID = 77, accountInfo = { battleTag = "Other#5678", gameAccountInfo = gameInfo("Thrall") } },
  }
end

local function conversations()
  return {
    [FRIEND_KEY] = { channel = "BN", battleTag = "Friend#1234", displayName = "Friend#1234", messages = {} },
    [STRANGER_KEY] = { channel = "BN", battleTag = "Gone#9999", displayName = "Gone#9999", messages = {} },
    [WHISPER_KEY] = { channel = "WOW", displayName = "Arthas-Area52", messages = {} },
  }
end

-- runtime.refreshWindow spy; records each call's dirty keys (false for nil,
-- which is the full rebuild that also redraws the selected chat's header).
local function makeBootstrap(store, visible)
  local refreshes = {}
  local Bootstrap = {
    runtime = {
      bnetApi = {},
      characterMerges = CharacterMergeMap.Ensure({}),
      store = store,
      isWindowVisible = function()
        return visible
      end,
      refreshWindow = function(_focusKey, dirtyKeys)
        refreshes[#refreshes + 1] = dirtyKeys or false
      end,
    },
  }
  return Bootstrap, refreshes
end

-- Each entry changes one thing the open window shows for Friend#1234.
local VISIBLE_CHANGES = {
  {
    name = "friend_comes_online",
    before = function(friend)
      friend.accountInfo.gameAccountInfo = { isOnline = false }
    end,
    change = function(friend)
      friend.accountInfo.gameAccountInfo = gameInfo("Jaina")
    end,
  },
  {
    name = "friend_goes_offline",
    change = function(friend)
      friend.accountInfo.gameAccountInfo = { isOnline = false }
      friend.accountInfo.lastOnlineTime = 1234
    end,
  },
  {
    name = "friend_opens_the_app_only",
    before = function(friend)
      friend.accountInfo.gameAccountInfo = { isOnline = false }
    end,
    change = function(friend)
      friend.accountInfo.gameAccountInfo = { isOnline = true, clientProgram = "App" }
    end,
  },
  {
    name = "friend_goes_away",
    change = function(friend)
      friend.accountInfo.isAFK = true
    end,
  },
  {
    name = "friend_goes_away_in_game",
    change = function(friend)
      friend.accountInfo.gameAccountInfo.isGameAFK = true
    end,
  },
  {
    name = "friend_goes_busy",
    change = function(friend)
      friend.accountInfo.isDND = true
    end,
  },
  {
    name = "friend_goes_busy_in_game",
    change = function(friend)
      friend.accountInfo.gameAccountInfo.isGameBusy = true
    end,
  },
  {
    name = "friend_switches_character",
    change = function(friend)
      friend.accountInfo.gameAccountInfo = gameInfo("Khadgar")
    end,
  },
  {
    name = "friend_class_changes",
    change = function(friend)
      friend.accountInfo.gameAccountInfo.className = "Warlock"
    end,
  },
  {
    name = "friend_levels_up",
    change = function(friend)
      friend.accountInfo.gameAccountInfo.characterLevel = 81
    end,
  },
  {
    name = "friend_changes_zone",
    change = function(friend)
      friend.accountInfo.gameAccountInfo.areaName = "Isle of Dorn"
    end,
  },
  {
    name = "friend_changes_realm",
    change = function(friend)
      friend.accountInfo.gameAccountInfo.realmName = "Stormrage"
    end,
  },
  {
    name = "friend_switches_game",
    before = function(friend)
      friend.accountInfo.gameAccountInfo = { isOnline = true, clientProgram = "App" }
    end,
    change = function(friend)
      friend.accountInfo.gameAccountInfo.clientProgram = "Hero"
    end,
  },
  {
    name = "friend_account_id_changes",
    change = function(friend)
      friend.bnetAccountID = 43
    end,
  },
}

return function()
  -- Force the synchronous fallback path: without C_Timer the debounce runs
  -- the scan immediately.
  local savedCTimer = rawget(_G, "C_Timer")
  rawset(_G, "C_Timer", nil)

  -- test_visible_window_skips_refresh_when_no_bnet_conversation_changed
  do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, true)
    local deps = makeDeps(friendMap())
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    assert(#refreshes == 1 and refreshes[1] == false, "test precondition: the first scan rebuilds the open window")

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#refreshes == 1, "a scan that changed nothing leaves the open window alone, got " .. #refreshes .. " refreshes")
  end

  -- test_visible_window_skips_refresh_when_only_a_friend_without_a_conversation_changed
  do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, true)
    local friends = friendMap()
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    friends["Other#5678"].accountInfo.isAFK = true
    friends["Other#5678"].accountInfo.gameAccountInfo.areaName = "Isle of Dorn"
    friends["New#0001"] = { bnetAccountID = 99, accountInfo = { battleTag = "New#0001", gameAccountInfo = gameInfo("Anduin") } }
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    assert(#refreshes == 1, "a friend with no conversation is not on screen, got " .. #refreshes .. " refreshes")
  end

  -- test_visible_window_refreshes_when_<change>, one per VISIBLE_CHANGES entry
  for _, case in ipairs(VISIBLE_CHANGES) do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, true)
    local friends = friendMap()
    if case.before then
      case.before(friends["Friend#1234"])
    end
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    case.change(friends["Friend#1234"])
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    assert(#refreshes == 2, case.name .. ": the open window must refresh, got " .. #refreshes .. " refreshes")
    assert(refreshes[2] == false, case.name .. ": the refresh rebuilds every contact and the header")

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))
    assert(#refreshes == 2, case.name .. ": the change refreshes once, got " .. #refreshes .. " refreshes")
  end

  -- test_visible_window_refreshes_when_battle_tag_is_renamed
  -- The conversation's battleTag no longer names a friend, so its live
  -- status falls back to offline: once, not on every later scan.
  do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, true)
    local friends = friendMap()
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    friends["Renamed#1234"] = friends["Friend#1234"]
    friends["Friend#1234"] = nil
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    assert(#refreshes == 2 and refreshes[2] == false, "a renamed or removed friend refreshes the open window, got " .. #refreshes)

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))
    assert(#refreshes == 2, "a conversation with no friend refreshes once, got " .. #refreshes .. " refreshes")
  end

  -- test_visible_window_refreshes_when_orphan_is_rekeyed
  do
    local canonicalKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(913, { battleTag = "Solo#5678" }).contactKey)
    local numericKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(913, nil).contactKey)
    local store = { conversations = conversations() }
    local friends = friendMap()
    friends["Solo#5678"] = { bnetAccountID = 913, accountInfo = { battleTag = "Solo#5678" } }
    local Bootstrap, refreshes = makeBootstrap(store, true)
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    store.conversations[numericKey] = { channel = "BN", bnetAccountID = 913, displayName = "913", messages = {}, lastActivityAt = 7 }
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    assert(store.conversations[canonicalKey] ~= nil, "test precondition: the orphan moved to the battleTag key")
    assert(#refreshes == 2 and refreshes[2] == false, "an account-ID rekey refreshes the open window, got " .. #refreshes)
  end

  -- test_signature_is_dropped_when_conversation_is_deleted
  -- A chat that is deleted and started again carries the same stored fields,
  -- so only a dropped signature makes the scan notice it is new.
  do
    local store = { conversations = conversations() }
    local Bootstrap, refreshes = makeBootstrap(store, true)
    local deps = makeDeps(friendMap())
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    local deleted = store.conversations[FRIEND_KEY]

    store.conversations[FRIEND_KEY] = nil
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    store.conversations[FRIEND_KEY] = deleted
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#refreshes == 2, "a conversation that came back refreshes the open window, got " .. #refreshes .. " refreshes")
  end

  -- test_hidden_window_still_ignores_a_live_only_change
  -- Away shows only in the open window, so a closed one is left alone.
  do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, false)
    local friends = friendMap()
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    friends["Friend#1234"].accountInfo.isAFK = true
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    assert(#refreshes == 1, "a live-only change leaves the closed window alone, got " .. #refreshes .. " refreshes")
  end

  rawset(_G, "C_Timer", savedCTimer)
end
