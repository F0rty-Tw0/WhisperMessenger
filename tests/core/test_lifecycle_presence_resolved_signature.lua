-- The open window draws what BNetResolver.ResolveAccountInfo answers, not
-- the friend-list entry's primary game account. A Battle.net friend scan
-- must notice a change in that answer, with the real resolver.

local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local ScanWorld = require("tests.helpers.bnet_scan_world")
local FriendList = require("tests.helpers.bnet_friend_list")

local deps = { loadModule = require }

-- The friend's primary game account is the Battle.net app; a second one is
-- in WoW. Returns Bootstrap, refreshes, gameAccounts.
local function appPrimaryWowSecond()
  local gameAccounts = { ScanWorld.AppAccount(), ScanWorld.WowAccount("Jaina") }
  local Bootstrap, refreshes = ScanWorld.Bootstrap(ScanWorld.NewApi(ScanWorld.Account(), gameAccounts), ScanWorld.Store(), true)
  Presence.handleBNetFriendEvent(Bootstrap, deps)
  assert(#refreshes == 1, "test precondition: the first scan rebuilds the open window")
  return Bootstrap, refreshes, gameAccounts
end

-- Scans a friend list of friendCount with a conversation for the last
-- chatCount friends (the costliest to find without an index), twice. Returns the API call counts of the second scan.
local function secondScanCalls(friendCount, chatCount)
  local states = {}
  for id = 1, friendCount do
    states[id] = (id % 3 == 0 and "wow") or (id % 3 == 1 and "app") or "offline"
  end
  local bnetApi, calls = FriendList.NewApi(states)
  local store = { conversations = {} }
  for id = friendCount - chatCount + 1, friendCount do
    local contact = FriendList.Contact(id)
    store.conversations[contact.conversationKey] =
      { channel = "BN", bnetAccountID = id, battleTag = contact.battleTag, displayName = contact.displayName, messages = {} }
  end
  local Bootstrap = ScanWorld.Bootstrap(bnetApi, store, true)
  Presence.handleBNetFriendEvent(Bootstrap, deps)
  local friendInfoBefore, accountByIdBefore = calls.friendInfo, calls.accountById

  Presence.handleBNetFriendEvent(Bootstrap, deps)

  return calls.friendInfo - friendInfoBefore, calls.accountById - accountByIdBefore
end

return function()
  local savedCTimer = rawget(_G, "C_Timer")
  rawset(_G, "C_Timer", nil) -- scans run synchronously

  -- test_visible_window_refreshes_when_second_game_account_changes_zone
  do
    local Bootstrap, refreshes, gameAccounts = appPrimaryWowSecond()

    gameAccounts[2].areaName = "Isle of Dorn"
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#refreshes == 2 and refreshes[2] == false, "a zone change on the WoW account must refresh, got " .. #refreshes .. " refreshes")
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    assert(#refreshes == 2, "the change refreshes once, got " .. #refreshes .. " refreshes")
  end

  -- test_visible_window_refreshes_when_second_game_account_switches_character
  do
    local Bootstrap, refreshes, gameAccounts = appPrimaryWowSecond()

    gameAccounts[2].characterName = "Thrall"
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#refreshes == 2 and refreshes[2] == false, "a character swap on the WoW account must refresh, got " .. #refreshes .. " refreshes")
  end

  -- test_visible_window_refreshes_when_second_game_account_logs_out_of_wow
  do
    local Bootstrap, refreshes, gameAccounts = appPrimaryWowSecond()

    gameAccounts[2] = nil
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#refreshes == 2 and refreshes[2] == false, "leaving WoW with the app still open must refresh, got " .. #refreshes .. " refreshes")
  end

  -- test_visible_window_refreshes_when_renamed_friend_resolved_by_guid_changes
  -- The stored battleTag no longer names a friend; the window still reads the
  -- friend through the stored account ID and character GUID.
  do
    local account = ScanWorld.Account()
    account.battleTag = "Renamed#9999"
    local bnetApi = ScanWorld.NewApi(account, { ScanWorld.WowAccount("Jaina") })
    local Bootstrap, refreshes = ScanWorld.Bootstrap(bnetApi, ScanWorld.Store({ guid = "Player-1-0001" }), true)
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    assert(#refreshes == 1, "the renamed friend's first scan rebuilds the open window, got " .. #refreshes .. " refreshes")

    account.isAFK = true
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#refreshes == 2 and refreshes[2] == false, "the renamed friend going away must refresh, got " .. #refreshes .. " refreshes")
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    assert(#refreshes == 2, "the change refreshes once, got " .. #refreshes .. " refreshes")
  end

  -- test_scan_walks_the_friend_list_a_fixed_number_of_times
  -- One walk builds the friend map and at most one more serves every
  -- conversation's lookup: the cost must not grow as chats x friends.
  do
    local FRIENDS = 200
    local friendInfo20, accountById20 = secondScanCalls(FRIENDS, 20)
    local friendInfo40, accountById40 = secondScanCalls(FRIENDS, 40)

    assert(friendInfo20 <= 2 * FRIENDS, "20 chats: at most two friend-list walks per scan, got " .. friendInfo20 .. " friend reads")
    assert(friendInfo40 == friendInfo20, "friend reads must not grow with the chat count, got " .. friendInfo40 .. " for 40 chats")
    assert(accountById20 == 20 and accountById40 == 40, "one account lookup per chat, got " .. accountById20 .. " and " .. accountById40)
  end

  rawset(_G, "C_Timer", savedCTimer)
end
