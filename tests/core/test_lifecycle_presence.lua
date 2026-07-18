local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local Identity = require("WhisperMessenger.Model.Identity")

local function makeDeps(friendMap)
  return {
    trace = function() end,
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

local function makeHarness(gameAccountInfo)
  local conversation = {
    channel = "BN",
    battleTag = "Friend#1234",
    gameAccountName = "Charname-Stormrage",
  }
  local Bootstrap = {
    runtime = {
      bnetApi = {},
      store = { conversations = { ["bn::friend"] = conversation } },
    },
  }
  local deps = makeDeps({
    ["Friend#1234"] = {
      bnetAccountID = 42,
      accountInfo = { battleTag = "Friend#1234", gameAccountInfo = gameAccountInfo },
    },
  })
  return Bootstrap, deps, conversation
end

return function()
  -- Force the synchronous fallback path: without C_Timer the debounce runs
  -- the scan immediately, which the assertions below rely on.
  local savedCTimer = rawget(_G, "C_Timer")
  rawset(_G, "C_Timer", nil)

  -- test_bnet_friend_update_applies_real_character_name
  do
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "Newchar",
      realmName = "Area52",
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(
      conversation.gameAccountName == "Newchar-Area52",
      "real character info updates the stored name; got: " .. tostring(conversation.gameAccountName)
    )
    assert(conversation.bnetAccountID == 42, "bnetAccountID refreshes from the friend list")
  end

  -- test_bnet_friend_offline_empty_strings_keep_stored_name
  do
    -- The BNet API reports empty strings (not nil) when the friend is not
    -- in WoW; those must not clobber the stored character name.
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "",
      realmName = "",
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(
      conversation.gameAccountName == "Charname-Stormrage",
      "empty characterName must not clobber the stored name; got: " .. tostring(conversation.gameAccountName)
    )
  end

  -- test_bnet_friend_missing_realm_stores_bare_character_name
  do
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "Newchar",
      realmName = "",
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(
      conversation.gameAccountName == "Newchar",
      "empty realmName stores the bare character name; got: " .. tostring(conversation.gameAccountName)
    )
  end

  -- test_orphaned_numeric_bnet_conversation_merges_into_battletag_thread
  -- A BN whisper stored before the friend list resolved is keyed by the
  -- session-scoped numeric account ID; once the friend list is available
  -- the thread must fold into the stable battleTag conversation.
  do
    local canonicalKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(912, { battleTag = "Friend#1234" }).contactKey)
    local numericKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(912, nil).contactKey)
    assert(numericKey ~= canonicalKey, "test precondition: numeric and battleTag keys differ")

    local conversations = {
      [numericKey] = {
        channel = "BN",
        bnetAccountID = 912,
        displayName = "912",
        unreadCount = 1,
        messages = { { sentAt = 5, text = "early" } },
        lastActivityAt = 5,
      },
      [canonicalKey] = {
        channel = "BN",
        battleTag = "Friend#1234",
        bnetAccountID = 912,
        unreadCount = 2,
        messages = { { sentAt = 10, text = "later" } },
        lastActivityAt = 10,
      },
    }
    local Bootstrap = { runtime = { bnetApi = {}, store = { conversations = conversations } } }
    local deps = makeDeps({
      ["Friend#1234"] = { bnetAccountID = 912, accountInfo = { battleTag = "Friend#1234" } },
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(conversations[numericKey] == nil, "numeric-key orphan should be folded away")
    local merged = conversations[canonicalKey]
    assert(merged ~= nil, "battleTag conversation should survive")
    assert(#merged.messages == 2, "messages from both threads survive; got " .. tostring(#merged.messages))
    assert(merged.messages[1].text == "early" and merged.messages[2].text == "later", "merged messages are chronological")
    assert(merged.unreadCount == 3, "unread counts combine; got " .. tostring(merged.unreadCount))
  end

  -- test_orphaned_numeric_bnet_conversation_rekeys_when_no_existing_thread
  do
    local canonicalKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(913, { battleTag = "Solo#5678" }).contactKey)
    local numericKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(913, nil).contactKey)

    local conversations = {
      [numericKey] = {
        channel = "BN",
        bnetAccountID = 913,
        displayName = "913",
        messages = { { sentAt = 7, text = "hi" } },
        lastActivityAt = 7,
      },
    }
    local Bootstrap = { runtime = { bnetApi = {}, store = { conversations = conversations } } }
    local deps = makeDeps({
      ["Solo#5678"] = { bnetAccountID = 913, accountInfo = { battleTag = "Solo#5678" } },
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(conversations[numericKey] == nil, "numeric key should be gone")
    local moved = conversations[canonicalKey]
    assert(moved ~= nil, "conversation should move to the battleTag key")
    assert(moved.battleTag == "Solo#5678", "battleTag is stamped on the moved conversation")
    assert(moved.displayName == "Solo#5678", "numeric display name upgrades to the battleTag")
  end

  -- test_bnet_friend_events_debounce_into_one_scan
  -- BN_FRIEND_INFO_CHANGED fires in bursts; the full friend-list scan must
  -- coalesce into one deferred pass instead of running per event.
  do
    local scans = 0
    local deps = {
      trace = function() end,
      loadModule = function(modulePath)
        if string.find(modulePath, "BNetResolver", 1, true) then
          return {
            ScanFriendList = function()
              scans = scans + 1
              return {}
            end,
          }
        end
        return require(modulePath)
      end,
    }
    local Bootstrap = { runtime = { bnetApi = {}, store = { conversations = {} } } }

    local capturedCallbacks = {}
    rawset(_G, "C_Timer", {
      After = function(_seconds, callback)
        table.insert(capturedCallbacks, callback)
      end,
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(scans == 0, "scan is deferred, not run per event; got " .. tostring(scans))
    assert(#capturedCallbacks == 1, "burst coalesces into one timer; got " .. tostring(#capturedCallbacks))

    capturedCallbacks[1]()
    assert(scans == 1, "deferred callback runs exactly one scan; got " .. tostring(scans))

    Presence.handleBNetFriendEvent(Bootstrap, deps)
    assert(#capturedCallbacks == 2, "a later event schedules a fresh scan")

    rawset(_G, "C_Timer", nil)
  end

  rawset(_G, "C_Timer", savedCTimer)
end
