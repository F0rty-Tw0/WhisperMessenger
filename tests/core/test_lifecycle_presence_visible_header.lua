-- End to end with the real coordinator, enricher and resolver: a Battle.net
-- friend scan redraws the open window's selected chat when the friend's live
-- state changed, and leaves the window alone when it did not.

local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local SnapshotCache = require("WhisperMessenger.UI.ContactsList.SnapshotCache")

local FRIEND_KEY = "bnet::friend"

local function makeHarness()
  local friend = {
    bnetAccountID = 42,
    battleTag = "Friend#1234",
    isAFK = false,
    gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Jaina", realmName = "Area52", areaName = "Dornogal" },
  }
  -- Like the game, every call hands out a fresh table: the resolver writes
  -- what it works out into the one it is given.
  local function accountInfo()
    local info, game = {}, {}
    for field, value in pairs(friend) do
      info[field] = value
    end
    for field, value in pairs(friend.gameAccountInfo) do
      game[field] = value
    end
    info.gameAccountInfo = game
    return info
  end
  local bnetApi = {
    GetNumFriends = function()
      return 1
    end,
    GetFriendAccountInfo = accountInfo,
    GetAccountInfoByID = accountInfo,
  }
  local store = {
    conversations = {
      [FRIEND_KEY] = { channel = "BN", battleTag = "Friend#1234", bnetAccountID = 42, displayName = "Friend#1234", messages = {} },
    },
  }
  local accountState = { conversations = store.conversations, settings = {} }
  local runtime = {
    store = store,
    accountState = accountState,
    bnetApi = bnetApi,
    activeConversationKey = FRIEND_KEY,
    sendStatusByConversation = {},
    availabilityByGUID = {},
  }
  local selections = {}
  local window = {
    frame = {
      IsShown = function()
        return true
      end,
    },
    refreshSelection = function(state)
      selections[#selections + 1] = state
    end,
  }
  local cache = SnapshotCache.New()
  local coordinator = WindowCoordinator.Create({
    runtime = runtime,
    buildContacts = function(dirtyKeys)
      return DataBuilder.BuildItemsForProfile(accountState, "me", cache, dirtyKeys)
    end,
    getWindow = function()
      return window
    end,
    getIcon = function()
      return nil
    end,
    cTimer = {
      NewTicker = function()
        return { Cancel = function() end }
      end,
    },
  })
  runtime.isWindowVisible = coordinator.isWindowVisible
  runtime.refreshWindow = function(focusKey, dirtyKeys)
    return coordinator.refreshWindow(focusKey, dirtyKeys)
  end
  return { runtime = runtime }, friend, selections
end

return function()
  -- Force the synchronous fallback path: without C_Timer the debounce runs
  -- the scan immediately.
  local savedCTimer = rawget(_G, "C_Timer")
  rawset(_G, "C_Timer", nil)
  local deps = { loadModule = require }

  -- test_visible_scan_redraws_the_selected_header_when_the_friend_changes_realm
  do
    local Bootstrap, friend, selections = makeHarness()
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    assert(#selections == 1, "test precondition: the first scan draws the selected chat, got " .. #selections)
    assert(selections[1].selectedContact.realm == "Area52", "test precondition: the header shows the friend's realm")

    friend.gameAccountInfo.realmName = "Stormrage"
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#selections == 2, "the realm change redraws the selected chat, got " .. #selections)
    assert(selections[2].selectedContact.realm == "Stormrage", "the header shows the new realm")
  end

  -- test_visible_scan_redraws_the_selected_status_when_the_friend_goes_away
  do
    local Bootstrap, friend, selections = makeHarness()
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    local statusBefore = selections[1].status and selections[1].status.status

    friend.isAFK = true
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#selections == 2, "going away redraws the selected chat, got " .. #selections)
    local statusAfter = selections[2].status and selections[2].status.status
    assert(statusBefore == "CanWhisper" and statusAfter == "Away", "status went " .. tostring(statusBefore) .. " -> " .. tostring(statusAfter))
  end

  -- test_visible_scan_leaves_the_window_alone_when_nothing_changed
  do
    local Bootstrap, _friend, selections = makeHarness()
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    Presence.handleBNetFriendEvent(Bootstrap, deps)
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#selections == 1, "a scan that changed nothing does not redraw the window, got " .. #selections)
  end

  rawset(_G, "C_Timer", savedCTimer)
end
