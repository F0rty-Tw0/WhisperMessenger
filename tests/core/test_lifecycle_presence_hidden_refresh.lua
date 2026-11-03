-- A Battle.net friend scan while the messenger is closed rebuilds only the
-- conversations the scan changed: the closed window shows just the icon
-- badges and preview, and opening it rebuilds every contact anyway.

local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local Identity = require("WhisperMessenger.Model.Identity")
local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local SnapshotCache = require("WhisperMessenger.UI.ContactsList.SnapshotCache")
local PerfCounters = require("WhisperMessenger.Util.PerfCounters")

local FRIEND_KEY = "bnet::friend"
local STRANGER_KEY = "bnet::stranger"
local WHISPER_KEY = "wow::WOW::arthas-area52"

local function makeDeps(friendMap)
  return {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetResolver", 1, true) then
        return {
          ScanFriendList = function()
            return friendMap
          end,
        }
      end
      return require(modulePath)
    end,
  }
end

local function friendMap()
  return {
    ["Friend#1234"] = {
      bnetAccountID = 42,
      accountInfo = { battleTag = "Friend#1234", gameAccountInfo = { characterName = "Newchar", realmName = "Area52" } },
    },
  }
end

local function conversations()
  return {
    [FRIEND_KEY] = { channel = "BN", battleTag = "Friend#1234", displayName = "Friend#1234", messages = {} },
    [STRANGER_KEY] = { channel = "BN", battleTag = "Gone#9999", displayName = "Gone#9999", messages = {} },
    [WHISPER_KEY] = { channel = "WOW", displayName = "Arthas-Area52", messages = {} },
  }
end

-- runtime.refreshWindow spy; records each call's dirty keys (false for nil).
local function makeBootstrap(store, visible)
  local refreshes = {}
  local Bootstrap = {
    runtime = {
      bnetApi = {},
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

local function countKeys(set)
  local count = 0
  for _ in pairs(set) do
    count = count + 1
  end
  return count
end

return function()
  -- Force the synchronous fallback path: without C_Timer the debounce runs
  -- the scan immediately.
  local savedCTimer = rawget(_G, "C_Timer")
  rawset(_G, "C_Timer", nil)

  -- test_hidden_bnet_scan_rebuilds_only_scanned_friend_conversations
  do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, false)

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friendMap()))

    assert(#refreshes == 1, "one refresh per scan, got " .. #refreshes)
    local dirtyKeys = refreshes[1]
    assert(type(dirtyKeys) == "table", "a hidden scan passes dirty keys, not a full rebuild")
    assert(dirtyKeys[FRIEND_KEY] == true, "the scanned friend's conversation is rebuilt")
    assert(countKeys(dirtyKeys) == 1, "only the scanned friend's conversation is rebuilt, got " .. countKeys(dirtyKeys))
  end

  -- test_hidden_bnet_scan_without_changes_skips_the_refresh
  do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, false)
    local deps = makeDeps(friendMap())
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#refreshes == 1, "a scan that changed nothing leaves the closed window alone, got " .. #refreshes .. " refreshes")
  end

  -- test_hidden_bnet_scan_that_only_restamps_last_seen_skips_the_refresh
  -- "Last seen" shows only in the open window's header, so a watched online
  -- friend's re-stamp must not rebuild a closed window's card on every scan.
  do
    local store = { conversations = conversations() }
    local friend = store.conversations[FRIEND_KEY]
    friend.notifyOnline = true
    local Bootstrap, refreshes = makeBootstrap(store, false)
    local clock = 100
    Bootstrap.runtime.now = function()
      clock = clock + 1
      return clock
    end
    local friends = friendMap()
    friends["Friend#1234"].accountInfo.isOnline = true
    local deps = makeDeps(friends)
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    local firstSeenAt = friend.lastSeenAt

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(firstSeenAt ~= nil and friend.lastSeenAt ~= firstSeenAt, "test precondition: the second scan re-stamped last seen")
    assert(#refreshes == 1, "a scan that only re-stamps last seen leaves the closed window alone, got " .. #refreshes .. " refreshes")
  end

  -- test_hidden_bnet_scan_marks_a_cleared_field_dirty
  do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, false)
    local friends = friendMap()
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    friends["Friend#1234"].bnetAccountID = nil
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friends))

    assert(#refreshes == 2, "a field the scan cleared refreshes the closed window, got " .. #refreshes .. " refreshes")
    assert(refreshes[2][FRIEND_KEY] == true, "the friend whose field cleared is rebuilt")
  end

  -- test_visible_bnet_scan_refreshes_every_contact
  do
    local Bootstrap, refreshes = makeBootstrap({ conversations = conversations() }, true)

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friendMap()))

    assert(#refreshes == 1, "one refresh per scan, got " .. #refreshes)
    assert(refreshes[1] == false, "an open window still rebuilds every contact")
  end

  -- test_hidden_bnet_scan_marks_rekeyed_conversation_dirty
  do
    local canonicalKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(913, { battleTag = "Solo#5678" }).contactKey)
    local numericKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(913, nil).contactKey)
    local store = {
      conversations = {
        [numericKey] = { channel = "BN", bnetAccountID = 913, displayName = "913", messages = {}, lastActivityAt = 7 },
      },
    }
    local Bootstrap, refreshes = makeBootstrap(store, false)

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps({ ["Solo#5678"] = { bnetAccountID = 913, accountInfo = { battleTag = "Solo#5678" } } }))

    assert(store.conversations[canonicalKey] ~= nil, "test precondition: the orphan moved to the battleTag key")
    assert(type(refreshes[1]) == "table" and refreshes[1][canonicalKey] == true, "the rekeyed conversation is rebuilt")
  end

  -- test_hidden_bnet_scan_marks_merged_rekey_destination_dirty
  -- The orphan folds into an existing battleTag thread: the same table, now
  -- holding the merged unread and preview, must not keep its old card.
  do
    local canonicalKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(914, { battleTag = "Merge#5678" }).contactKey)
    local numericKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(914, nil).contactKey)
    local store = {
      conversations = {
        [numericKey] = { channel = "BN", bnetAccountID = 914, unreadCount = 1, messages = {}, lastActivityAt = 9 },
        [canonicalKey] = { channel = "BN", battleTag = "Merge#5678", bnetAccountID = 914, unreadCount = 0, messages = {}, lastActivityAt = 5 },
      },
    }
    local Bootstrap, refreshes = makeBootstrap(store, false)

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps({ ["Merge#5678"] = { bnetAccountID = 914, accountInfo = { battleTag = "Merge#5678" } } }))

    assert(store.conversations[numericKey] == nil, "test precondition: the orphan merged away")
    assert(type(refreshes[1]) == "table" and refreshes[1][canonicalKey] == true, "the merged thread is rebuilt")
  end

  -- test_hidden_bnet_scan_builds_one_snapshot_through_the_coordinator
  -- End to end with the real coordinator and snapshot cache: after the first
  -- full build, a hidden scan rebuilds the friend's card and reuses the rest.
  do
    local store = { conversations = conversations() }
    local accountState = { conversations = store.conversations, settings = {} }
    local cache = SnapshotCache.New()
    local coordinator = WindowCoordinator.Create({
      runtime = { store = store, sendStatusByConversation = {} },
      buildContacts = function(dirtyKeys)
        return DataBuilder.BuildItemsForProfile(accountState, "me", cache, dirtyKeys)
      end,
      getWindow = function()
        return nil
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
    local Bootstrap = {
      runtime = {
        bnetApi = {},
        store = store,
        isWindowVisible = coordinator.isWindowVisible,
        refreshWindow = function(focusKey, dirtyKeys)
          return coordinator.refreshWindow(focusKey, dirtyKeys)
        end,
      },
    }
    coordinator.refreshWindow()
    PerfCounters.Reset()

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friendMap()))

    local builds = PerfCounters.Get("snapshotBuilds")
    assert(builds == 1, "a hidden scan rebuilds one of three cards, got " .. tostring(builds))

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friendMap()))

    builds = PerfCounters.Get("snapshotBuilds")
    assert(builds == 1, "a repeat scan with no changes rebuilds nothing, got " .. tostring(builds))
  end

  rawset(_G, "C_Timer", savedCTimer)
end
