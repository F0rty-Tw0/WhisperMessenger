-- Where a Battle.net friend scan signs the live state an open window draws:
-- not at all while the window is closed, from scratch on the first scan
-- after it opens, and only after the conversation's notify bookkeeping.

local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local OnlineNotify = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.OnlineNotify")
local FakeScanResolver = require("tests.helpers.fake_scan_resolver")
local ScanWorld = require("tests.helpers.bnet_scan_world")
local FriendList = require("tests.helpers.bnet_friend_list")

local deps = { loadModule = require }

local FRIENDS = 30
local CHATS = 5

-- A closed window over FRIENDS friends in WoW, with a conversation for the
-- first CHATS of them. Returns Bootstrap, calls (the API call counters).
local function closedWindowWithChats()
  local states = {}
  for id = 1, FRIENDS do
    states[id] = "wow"
  end
  local bnetApi, calls = FriendList.NewApi(states)
  local store = { conversations = {} }
  for id = 1, CHATS do
    local contact = FriendList.Contact(id)
    store.conversations[contact.conversationKey] =
      { channel = "BN", bnetAccountID = id, battleTag = contact.battleTag, displayName = contact.displayName, messages = {} }
  end
  return ScanWorld.Bootstrap(bnetApi, store, false), calls
end

return function()
  local savedCTimer = rawget(_G, "C_Timer")
  rawset(_G, "C_Timer", nil) -- scans run synchronously

  -- test_hidden_scan_reads_the_friend_list_once_and_looks_up_no_account
  -- A closed window draws no live friend state, so the scan has nothing to
  -- resolve: one friend-list walk builds the friend map and that is all.
  do
    local Bootstrap, calls = closedWindowWithChats()

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(calls.accountById == 0, "a hidden scan looks up no account, got " .. calls.accountById .. " lookups")
    assert(calls.numGameAccounts == 0, "a hidden scan probes no game account, got " .. calls.numGameAccounts .. " probes")
    assert(calls.friendInfo == FRIENDS, "a hidden scan walks the friend list once, got " .. calls.friendInfo .. " friend reads")
  end

  -- test_first_visible_scan_after_reopen_redraws_a_change_made_while_hidden
  -- The friend went away while the window was closed and came back after it
  -- opened: the signature from before the window closed still says "not
  -- away", so only a fresh start tells the change.
  do
    local account = ScanWorld.Account()
    local bnetApi = ScanWorld.NewApi(account, { ScanWorld.WowAccount("Jaina") })
    local Bootstrap, refreshes = ScanWorld.Bootstrap(bnetApi, ScanWorld.Store(), true)
    local visible = true
    Bootstrap.runtime.isWindowVisible = function()
      return visible
    end
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    visible = false
    account.isAFK = true
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    visible = true -- opening drew the friend as away
    account.isAFK = false
    local refreshesBefore = #refreshes
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(#refreshes == refreshesBefore + 1, "the first scan after reopening must refresh, got " .. #refreshes - refreshesBefore .. " refreshes")
    assert(refreshes[#refreshes] == false, "the refresh rebuilds every contact and the header")
  end

  -- test_account_lookup_that_raises_does_not_skip_the_online_bookkeeping
  -- The lookup is only for the signature. The friend's "Notify when online"
  -- state is recorded first, so their next online event still alerts.
  do
    local lines = {}
    rawset(_G, "DEFAULT_CHAT_FRAME", {
      AddMessage = function(_, text)
        lines[#lines + 1] = text
      end,
    })
    local resolver = FakeScanResolver.New(function()
      return {
        [ScanWorld.BATTLE_TAG] = { bnetAccountID = ScanWorld.ACCOUNT_ID, accountInfo = { battleTag = ScanWorld.BATTLE_TAG, isOnline = false } },
      }
    end)
    resolver.ResolveAccountInfo = function()
      error("secret string compared")
    end
    local Bootstrap = ScanWorld.Bootstrap({}, ScanWorld.Store({ notifyOnline = true }), true)
    Bootstrap.runtime.accountState = { settings = {} }

    local scanned = pcall(Presence.handleBNetFriendEvent, Bootstrap, {
      loadModule = function(modulePath)
        if string.find(modulePath, "BNetResolver", 1, true) then
          return resolver
        end
        return require(modulePath)
      end,
    })
    assert(scanned == false, "test precondition: the account lookup raised")
    OnlineNotify.handleBNetAccountEvent(Bootstrap, ScanWorld.ACCOUNT_ID, true)

    assert(#lines == 1, "offline recorded by the failed scan, then online: one alert, got " .. #lines)
    rawset(_G, "DEFAULT_CHAT_FRAME", nil)
  end

  rawset(_G, "C_Timer", savedCTimer)
end
