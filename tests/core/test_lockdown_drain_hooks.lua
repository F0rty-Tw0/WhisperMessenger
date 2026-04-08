-- Tests for Phase 1 drain hooks: ENCOUNTER_END, ZONE_CHANGED_NEW_AREA,
-- PLAYER_ENTERING_WORLD, FIFO ordering, and queue cap eviction.

local Store = require("WhisperMessenger.Model.ConversationStore")

local EB_KEY = "WhisperMessenger.Core.Bootstrap.EventBridge"
local STG_KEY = "WhisperMessenger.Core.Bootstrap.SecretTaintGuard"
local FC_KEY = "WhisperMessenger.Core.FlavorCompat"
local LH_KEY = "WhisperMessenger.Core.Bootstrap.LifecycleHandlers"

local function reloadEventBridge()
  package.loaded[EB_KEY] = nil
  package.loaded[STG_KEY] = nil
  package.loaded[FC_KEY] = nil
  return require(EB_KEY)
end

local function reloadLifecycleHandlers()
  package.loaded[LH_KEY] = nil
  package.loaded[FC_KEY] = nil
  return require(LH_KEY)
end

local function makeRuntime()
  return {
    store = Store.New({ maxMessagesPerConversation = 50 }),
    localProfileId = "me",
    now = function()
      return 100
    end,
    availabilityByGUID = {},
    pendingOutgoing = {},
    accountState = { settings = {} },
    secretDeferredQueue = nil,
  }
end

local function whisperArgs(text, sender)
  return { text or "hello", sender or "Arthas-Area52", "", "", "", "", "", 0, "", 0, 1, "Player-3676-0ABCDEF0" }
end

local function setTaint(active)
  _G.hasanysecretvalues = function()
    return active
  end
end

local function setLockdown(active)
  _G.C_ChatInfo = {
    InChatMessagingLockdown = function()
      return active
    end,
  }
end

local function setOpenWorldInstance()
  _G.GetInstanceInfo = function()
    return "Eastern Kingdoms", "none", 0
  end
end

local function makeDeps(EventBridge)
  return {
    trace = function() end,
    getEventBridge = function()
      return EventBridge
    end,
    getContentDetector = function()
      return {
        IsCompetitiveContent = function(getInstanceInfo)
          local _, instanceType, difficultyID = getInstanceInfo()
          return instanceType == "pvp" or instanceType == "arena" or (instanceType == "party" and difficultyID == 8)
        end,
        IsMythicRestricted = function(getInstanceInfo)
          local _, instanceType, difficultyID = getInstanceInfo()
          return instanceType == "party" and difficultyID == 8
        end,
      }
    end,
    getPresenceCache = function()
      return nil
    end,
  }
end

local function enqueueOne(EventBridge, runtime, text, sender)
  EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(whisperArgs(text, sender)))
end

return function()
  local savedCTimer = _G.C_Timer
  _G.C_Timer = {
    After = function(_delay, fn)
      fn()
    end,
  }

  -- -------------------------------------------------------------------------
  -- test_drain_fires_on_encounter_end_when_unlocked
  -- -------------------------------------------------------------------------
  do
    local savedHas, savedChatInfo = _G.hasanysecretvalues, _G.C_ChatInfo

    setTaint(true)
    setLockdown(false)

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local runtime = makeRuntime()
    local Bootstrap = { runtime = runtime }

    enqueueOne(EventBridge, runtime, "secret", "Arthas-Area52")
    assert(#runtime.secretDeferredQueue == 1, "encounter_end_unlocked: expected 1 item queued")

    setTaint(false)
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps(EventBridge))

    assert(#runtime.secretDeferredQueue == 0, "encounter_end_unlocked: queue should be empty after ENCOUNTER_END")

    _G.hasanysecretvalues, _G.C_ChatInfo = savedHas, savedChatInfo
  end

  -- -------------------------------------------------------------------------
  -- test_drain_does_not_fire_on_encounter_end_while_locked
  -- -------------------------------------------------------------------------
  do
    local savedHas, savedChatInfo = _G.hasanysecretvalues, _G.C_ChatInfo

    setTaint(true)
    setLockdown(true)

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local runtime = makeRuntime()
    local Bootstrap = { runtime = runtime }

    enqueueOne(EventBridge, runtime, "secret", "Arthas-Area52")
    assert(#runtime.secretDeferredQueue == 1, "encounter_end_locked: expected 1 item queued")

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps(EventBridge))

    assert(#runtime.secretDeferredQueue == 1, "encounter_end_locked: queue should still have 1 item while locked")

    _G.hasanysecretvalues, _G.C_ChatInfo = savedHas, savedChatInfo
  end

  -- -------------------------------------------------------------------------
  -- test_drain_fires_on_bg_exit_zone_change
  -- -------------------------------------------------------------------------
  do
    local savedHas, savedChatInfo, savedInstance = _G.hasanysecretvalues, _G.C_ChatInfo, _G.GetInstanceInfo

    setTaint(true)
    setLockdown(false)
    setOpenWorldInstance()

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local runtime = makeRuntime()
    local Bootstrap = {
      runtime = runtime,
      lockdown = { active = true, since = 1, source = "PLAYER_ENTERING_WORLD" },
    }

    enqueueOne(EventBridge, runtime, "secret", "Arthas-Area52")
    assert(#runtime.secretDeferredQueue == 1, "bg_exit_zone_change: expected 1 item queued")

    setTaint(false)
    LifecycleHandlers.Handle(Bootstrap, "ZONE_CHANGED_NEW_AREA", makeDeps(EventBridge))

    assert(#runtime.secretDeferredQueue == 0, "bg_exit_zone_change: queue should be empty after zone change")

    _G.hasanysecretvalues, _G.C_ChatInfo, _G.GetInstanceInfo = savedHas, savedChatInfo, savedInstance
  end

  -- -------------------------------------------------------------------------
  -- test_drain_fires_on_player_entering_world_when_unlocked
  -- -------------------------------------------------------------------------
  do
    local savedHas, savedChatInfo, savedInstance = _G.hasanysecretvalues, _G.C_ChatInfo, _G.GetInstanceInfo

    setTaint(true)
    setLockdown(false)
    setOpenWorldInstance()

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local runtime = makeRuntime()
    local Bootstrap = { runtime = runtime }

    enqueueOne(EventBridge, runtime, "secret", "Arthas-Area52")
    assert(#runtime.secretDeferredQueue == 1, "player_entering_world: expected 1 item queued")

    setTaint(false)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps(EventBridge))

    assert(
      #runtime.secretDeferredQueue == 0,
      "player_entering_world: queue should be empty after PLAYER_ENTERING_WORLD"
    )

    _G.hasanysecretvalues, _G.C_ChatInfo, _G.GetInstanceInfo = savedHas, savedChatInfo, savedInstance
  end

  -- -------------------------------------------------------------------------
  -- test_drain_preserves_fifo_order
  -- -------------------------------------------------------------------------
  do
    local savedHas, savedIsSecret, savedChatInfo = _G.hasanysecretvalues, _G.issecretvalue, _G.C_ChatInfo

    setTaint(true)
    -- Keep sanitized args intact so text values survive into the drain.
    _G.issecretvalue = function()
      return false
    end

    local EventBridge = reloadEventBridge()
    local runtime = makeRuntime()

    enqueueOne(EventBridge, runtime, "first", "Sender-Realm")
    enqueueOne(EventBridge, runtime, "second", "Sender-Realm")
    enqueueOne(EventBridge, runtime, "third", "Sender-Realm")
    assert(#runtime.secretDeferredQueue == 3, "fifo: expected 3 queued items")

    setTaint(false)
    setLockdown(false)
    EventBridge.DrainSecretDeferredQueue(runtime, nil)

    local convKey = next(runtime.store.conversations)
    assert(convKey ~= nil, "fifo: expected a conversation after drain")
    local conv = runtime.store.conversations[convKey]
    assert(#conv.messages == 3, "fifo: expected 3 messages, got " .. #conv.messages)
    assert(conv.messages[1].text == "first", "fifo: message[1] should be 'first'")
    assert(conv.messages[2].text == "second", "fifo: message[2] should be 'second'")
    assert(conv.messages[3].text == "third", "fifo: message[3] should be 'third'")

    _G.hasanysecretvalues, _G.issecretvalue, _G.C_ChatInfo = savedHas, savedIsSecret, savedChatInfo
  end

  -- -------------------------------------------------------------------------
  -- test_queue_cap_evicts_oldest
  -- -------------------------------------------------------------------------
  do
    local savedHas, savedIsSecret = _G.hasanysecretvalues, _G.issecretvalue

    setTaint(true)
    _G.issecretvalue = function()
      return false
    end

    local EventBridge = reloadEventBridge()
    local runtime = makeRuntime()

    for i = 1, 201 do
      enqueueOne(EventBridge, runtime, "msg-" .. i, "Sender-Realm")
    end

    assert(#runtime.secretDeferredQueue == 200, "cap: expected 200 items, got " .. #runtime.secretDeferredQueue)
    local firstRemaining = runtime.secretDeferredQueue[1]
    assert(firstRemaining ~= nil, "cap: queue[1] should not be nil")
    assert(
      firstRemaining.args[1] == "msg-2",
      "cap: oldest evicted; first should be msg-2, got: " .. tostring(firstRemaining.args[1])
    )

    _G.hasanysecretvalues, _G.issecretvalue = savedHas, savedIsSecret
  end

  _G.C_Timer = savedCTimer
end
