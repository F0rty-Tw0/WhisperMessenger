-- Phase 2 taint coverage: validates that M+ suspend no longer unregisters
-- chat events, RouteChannelEvent defers tainted args, channel items are
-- dropped on drain, and Mythic raid ENCOUNTER_START/END manages _wmSuspended.

local Store = require("WhisperMessenger.Model.ConversationStore")

local EB_KEY = "WhisperMessenger.Core.Bootstrap.EventBridge"
local STG_KEY = "WhisperMessenger.Core.Bootstrap.SecretTaintGuard"
local FC_KEY = "WhisperMessenger.Core.FlavorCompat"
local LH_KEY = "WhisperMessenger.Core.Bootstrap.LifecycleHandlers"
local MSC_KEY = "WhisperMessenger.Core.Bootstrap.MythicSuspendController"

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

local function reloadMythicSuspendController()
  package.loaded[MSC_KEY] = nil
  return require(MSC_KEY)
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
  return { text or "hi", sender or "Arthas-Area52", "", "", "", "", "", 0, "", 0, 1, "Player-3676-0ABCDEF0" }
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

local function makeDeps(EventBridge)
  return {
    trace = function() end,
    getEventBridge = function()
      return EventBridge
    end,
    getContentDetector = function()
      return {
        IsCompetitiveContent = function()
          return false
        end,
        IsMythicRestricted = function()
          return false
        end,
      }
    end,
    getPresenceCache = function()
      return nil
    end,
  }
end

-- Records any EventBridge/chat-filter call into `calls` so suspend tests can
-- assert that the unregister paths are NOT taken post-Phase 2.
local function makeSuspendDeps(calls, notice)
  local function rec(name)
    return function()
      calls[#calls + 1] = name
    end
  end
  local hidden
  return {
    Bootstrap = {
      _loadFrame = {},
      unregisterChatFilters = rec("unregisterChatFilters"),
      registerChatFilters = rec("registerChatFilters"),
    },
    mythicPauseNotice = notice,
    isWindowVisible = function()
      return true
    end,
    setWindowVisible = function(v)
      hidden = (v == false)
    end,
    refreshWindow = function() end,
    getEventBridge = function()
      return {
        UnregisterLiveEvents = rec("UnregisterLiveEvents"),
        UnregisterSuspendableLifecycleEvents = rec("UnregisterSuspendableLifecycleEvents"),
        UnregisterChannelEvents = rec("UnregisterChannelEvents"),
        RegisterLiveEvents = rec("RegisterLiveEvents"),
        RegisterSuspendableLifecycleEvents = rec("RegisterSuspendableLifecycleEvents"),
        RegisterChannelEvents = rec("RegisterChannelEvents"),
      }
    end,
    print = function() end,
  }, function()
    return hidden
  end
end

return function()
  local savedCTimer = _G.C_Timer
  _G.C_Timer = {
    After = function(_d, fn)
      fn()
    end,
  }

  -- test_mythic_suspend_does_not_unregister_events
  do
    local saved = _G._wmSuspended
    local calls, runtime = {}, {}
    local deps = makeSuspendDeps(calls, nil)
    reloadMythicSuspendController().Attach(runtime, deps)
    runtime.suspend()

    local joined = table.concat(calls, ",")
    assert(
      not string.find(joined, "UnregisterLiveEvents", 1, true),
      "phase2: must not UnregisterLiveEvents, got: " .. joined
    )
    assert(
      not string.find(joined, "UnregisterSuspendableLifecycleEvents", 1, true),
      "phase2: must not UnregisterSuspendableLifecycleEvents, got: " .. joined
    )
    assert(
      not string.find(joined, "UnregisterChannelEvents", 1, true),
      "phase2: must not UnregisterChannelEvents, got: " .. joined
    )
    _G._wmSuspended = saved
  end

  -- test_mythic_suspend_still_hides_window_and_sets_flag
  do
    local saved = _G._wmSuspended
    local calls, runtime = {}, {}
    local deps, wasHidden = makeSuspendDeps(calls, "MYTHIC-NOTICE")
    reloadMythicSuspendController().Attach(runtime, deps)
    runtime.suspend()

    assert(wasHidden() == true, "phase2: suspend should hide the window")
    assert(_G._wmSuspended == true, "phase2: suspend should set _wmSuspended = true")
    assert(runtime.messagingNotice == "MYTHIC-NOTICE", "phase2: suspend should set pause notice")
    _G._wmSuspended = saved
  end

  -- test_route_channel_event_defers_tainted_args
  do
    local saved = _G.hasanysecretvalues
    setTaint(true)
    local EventBridge = reloadEventBridge()
    local runtime = makeRuntime()
    runtime.channelMessageStore = { entries = {}, baseIndex = {}, maxEntries = 10, ttl = 1800 }

    local result =
      EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_CHANNEL", "text", "sender-name", "", "2. Trade - Stormwind")

    assert(result == nil, "phase2: tainted channel event should return nil")
    assert(type(runtime.secretDeferredQueue) == "table", "phase2: queue should exist")
    assert(#runtime.secretDeferredQueue == 1, "phase2: expected 1 queued item")
    assert(runtime.secretDeferredQueue[1].eventName == "CHAT_MSG_CHANNEL", "phase2: preserve eventName")
    assert(runtime.secretDeferredQueue[1].isChannel == true, "phase2: should tag isChannel=true")
    _G.hasanysecretvalues = saved
  end

  -- test_channel_items_dropped_on_drain
  do
    local savedHas, savedIsSecret, savedChatInfo = _G.hasanysecretvalues, _G.issecretvalue, _G.C_ChatInfo
    setTaint(true)
    _G.issecretvalue = function()
      return false
    end

    local EventBridge = reloadEventBridge()
    local runtime = makeRuntime()
    runtime.channelMessageStore = { entries = {}, baseIndex = {}, maxEntries = 10, ttl = 1800 }

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(whisperArgs("w1", "whisper-sender")))
    EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_CHANNEL", "c1", "trade-sender", "", "2. Trade - Orgrimmar")
    EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_CHANNEL", "c2", "trade-sender", "", "2. Trade - Orgrimmar")
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(whisperArgs("w2", "whisper-sender")))
    assert(#runtime.secretDeferredQueue == 4, "phase2: expected 4 queued items")

    setTaint(false)
    setLockdown(false)
    EventBridge.DrainSecretDeferredQueue(runtime, nil)

    assert(#runtime.secretDeferredQueue == 0, "phase2: queue should be empty after drain")
    local count = 0
    for key in pairs(runtime.store.conversations) do
      count = count + 1
      assert(not string.find(string.lower(key), "trade-sender", 1, true), "phase2: no channel conv, got: " .. key)
    end
    assert(count == 1, "phase2: expected exactly 1 whisper conversation, got " .. count)

    _G.hasanysecretvalues, _G.issecretvalue, _G.C_ChatInfo = savedHas, savedIsSecret, savedChatInfo
  end

  -- test_encounter_start_sets_wmSuspended_when_locked
  do
    local savedSuspended, savedChatInfo = _G._wmSuspended, _G.C_ChatInfo
    setLockdown(true)
    _G._wmSuspended = nil

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local Bootstrap = { runtime = makeRuntime() }
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps(EventBridge))

    assert(_G._wmSuspended == true, "phase2: ENCOUNTER_START should set _wmSuspended when locked")
    assert(
      Bootstrap.lockdown and Bootstrap.lockdown.active == true,
      "phase2: lockdown.active should be true after locked ENCOUNTER_START"
    )
    assert(Bootstrap.lockdown.source == "ENCOUNTER_START", "phase2: lockdown.source should be ENCOUNTER_START")
    _G._wmSuspended, _G.C_ChatInfo = savedSuspended, savedChatInfo
  end

  -- test_encounter_end_clears_wmSuspended
  do
    local savedSuspended, savedChatInfo = _G._wmSuspended, _G.C_ChatInfo
    setLockdown(false)
    _G._wmSuspended = true

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local Bootstrap = {
      runtime = makeRuntime(),
      lockdown = { active = true, since = 1, source = "ENCOUNTER_START" },
    }
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps(EventBridge))

    assert(_G._wmSuspended == nil, "phase2: ENCOUNTER_END should clear _wmSuspended")
    assert(Bootstrap.lockdown.active == false, "phase2: lockdown.active should be false after ENCOUNTER_END")
    _G._wmSuspended, _G.C_ChatInfo = savedSuspended, savedChatInfo
  end

  _G.C_Timer = savedCTimer
end
