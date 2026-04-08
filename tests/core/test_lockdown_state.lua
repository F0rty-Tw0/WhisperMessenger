-- Tests for Phase 3 LockdownState: unified lockdown state machine driven by
-- FlavorCompat.InChatMessagingLockdown() with transition detection.

local Store = require("WhisperMessenger.Model.ConversationStore")

local LS_KEY = "WhisperMessenger.Core.Bootstrap.LockdownState"
local LH_KEY = "WhisperMessenger.Core.Bootstrap.LifecycleHandlers"
local FC_KEY = "WhisperMessenger.Core.FlavorCompat"
local EB_KEY = "WhisperMessenger.Core.Bootstrap.EventBridge"
local STG_KEY = "WhisperMessenger.Core.Bootstrap.SecretTaintGuard"

local function reloadLockdownState()
  package.loaded[LS_KEY] = nil
  return require(LS_KEY)
end

local function reloadLifecycleHandlers()
  package.loaded[LH_KEY] = nil
  package.loaded[FC_KEY] = nil
  return require(LH_KEY)
end

local function reloadEventBridge()
  package.loaded[EB_KEY] = nil
  package.loaded[STG_KEY] = nil
  package.loaded[FC_KEY] = nil
  return require(EB_KEY)
end

local function setLockdown(active)
  _G.C_ChatInfo = {
    InChatMessagingLockdown = function()
      return active
    end,
  }
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

local function makeDeps(EventBridge, now)
  return {
    trace = function() end,
    now = now,
    getEventBridge = function()
      return EventBridge
    end,
    getContentDetector = function()
      return {
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

return function()
  local savedCTimer = _G.C_Timer
  _G.C_Timer = {
    After = function(_d, fn)
      fn()
    end,
  }

  -- -------------------------------------------------------------------------
  -- test_initial_state_is_inactive
  -- -------------------------------------------------------------------------
  do
    local LockdownState = reloadLockdownState()
    local Bootstrap = {}
    LockdownState.Initialize(Bootstrap)

    assert(type(Bootstrap.lockdown) == "table", "initial: lockdown table should exist")
    assert(Bootstrap.lockdown.active == false, "initial: active should be false")
    assert(Bootstrap.lockdown.since == 0, "initial: since should be 0")
    assert(Bootstrap.lockdown.source == "init", 'initial: source should be "init"')
  end

  -- -------------------------------------------------------------------------
  -- test_is_active_returns_current_state
  -- -------------------------------------------------------------------------
  do
    local LockdownState = reloadLockdownState()
    local Bootstrap = {}
    LockdownState.Initialize(Bootstrap)
    assert(LockdownState.IsActive(Bootstrap) == false, "IsActive should return false initially")

    Bootstrap.lockdown.active = true
    assert(LockdownState.IsActive(Bootstrap) == true, "IsActive should read lockdown.active")
  end

  -- -------------------------------------------------------------------------
  -- test_sync_detects_false_to_true_transition
  -- -------------------------------------------------------------------------
  do
    local savedChatInfo = _G.C_ChatInfo
    setLockdown(true)

    local LockdownState = reloadLockdownState()
    local Bootstrap = {}
    LockdownState.Initialize(Bootstrap)

    local deps = {
      now = function()
        return 1234
      end,
    }
    local changed, wasActive, isActive = LockdownState.Sync(Bootstrap, "CHALLENGE_MODE_START", deps)

    assert(changed == true, "sync: should report changed=true on false->true")
    assert(wasActive == false, "sync: wasActive should be false (previous state)")
    assert(isActive == true, "sync: isActive should be true (new state)")
    assert(Bootstrap.lockdown.active == true, "sync: lockdown.active updated to true")
    assert(Bootstrap.lockdown.since == 1234, "sync: since should be set from deps.now")
    assert(Bootstrap.lockdown.source == "CHALLENGE_MODE_START", "sync: source should be updated")

    _G.C_ChatInfo = savedChatInfo
  end

  -- -------------------------------------------------------------------------
  -- test_sync_detects_true_to_false_transition
  -- -------------------------------------------------------------------------
  do
    local savedChatInfo = _G.C_ChatInfo
    setLockdown(false)

    local LockdownState = reloadLockdownState()
    local Bootstrap = {}
    LockdownState.Initialize(Bootstrap)
    Bootstrap.lockdown.active = true
    Bootstrap.lockdown.since = 500
    Bootstrap.lockdown.source = "CHALLENGE_MODE_START"

    local deps = {
      now = function()
        return 2000
      end,
    }
    local changed, wasActive, isActive = LockdownState.Sync(Bootstrap, "CHALLENGE_MODE_COMPLETED", deps)

    assert(changed == true, "sync: should report changed=true on true->false")
    assert(wasActive == true, "sync: wasActive should be true (previous state)")
    assert(isActive == false, "sync: isActive should be false (new state)")
    assert(Bootstrap.lockdown.active == false, "sync: lockdown.active updated to false")
    assert(Bootstrap.lockdown.since == 2000, "sync: since should be set from deps.now on transition")
    assert(Bootstrap.lockdown.source == "CHALLENGE_MODE_COMPLETED", "sync: source should be updated")

    _G.C_ChatInfo = savedChatInfo
  end

  -- -------------------------------------------------------------------------
  -- test_sync_noop_on_same_state
  -- -------------------------------------------------------------------------
  do
    local savedChatInfo = _G.C_ChatInfo
    setLockdown(false)

    local LockdownState = reloadLockdownState()
    local Bootstrap = {}
    LockdownState.Initialize(Bootstrap)
    -- First sync (false -> false, no change)
    local deps = {
      now = function()
        return 999
      end,
    }
    local changed, wasActive, isActive = LockdownState.Sync(Bootstrap, "PLAYER_ENTERING_WORLD", deps)

    assert(changed == false, "sync: no change on false->false")
    assert(wasActive == false, "sync: wasActive=false")
    assert(isActive == false, "sync: isActive=false")
    assert(Bootstrap.lockdown.since == 0, "sync: since should NOT update on no-op")
    assert(Bootstrap.lockdown.source == "init", "sync: source should NOT update on no-op")

    _G.C_ChatInfo = savedChatInfo
  end

  -- -------------------------------------------------------------------------
  -- test_handle_encounter_start_syncs_and_sets_wmSuspended_when_locked
  -- Integration via LifecycleHandlers.Handle
  -- -------------------------------------------------------------------------
  do
    local savedChatInfo, savedSuspended = _G.C_ChatInfo, _G._wmSuspended
    setLockdown(true)
    _G._wmSuspended = nil

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local LockdownState = reloadLockdownState()

    local Bootstrap = { runtime = makeRuntime() }
    LockdownState.Initialize(Bootstrap)

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps(EventBridge))

    assert(Bootstrap.lockdown.active == true, "encounter_start: lockdown.active should become true")
    assert(Bootstrap.lockdown.source == "ENCOUNTER_START", "encounter_start: source should be ENCOUNTER_START")
    assert(_G._wmSuspended == true, "encounter_start: _wmSuspended should be true when locked")

    _G.C_ChatInfo, _G._wmSuspended = savedChatInfo, savedSuspended
  end

  -- -------------------------------------------------------------------------
  -- test_handle_encounter_end_syncs_and_clears_wmSuspended_and_drains
  -- -------------------------------------------------------------------------
  do
    local savedChatInfo, savedSuspended = _G.C_ChatInfo, _G._wmSuspended
    local savedHas = _G.hasanysecretvalues

    -- Start with lockdown active, queue 1 tainted item
    setLockdown(true)
    _G.hasanysecretvalues = function()
      return true
    end

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local LockdownState = reloadLockdownState()

    local runtime = makeRuntime()
    local Bootstrap = { runtime = runtime }
    LockdownState.Initialize(Bootstrap)
    Bootstrap.lockdown.active = true
    Bootstrap.lockdown.source = "ENCOUNTER_START"
    _G._wmSuspended = true

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER",
      "hello",
      "Arthas-Area52",
      "",
      "",
      "",
      "",
      "",
      0,
      "",
      0,
      1,
      "Player-3676-0ABCDEF0"
    )
    assert(#runtime.secretDeferredQueue == 1, "encounter_end: expected 1 queued before end")

    -- Now clear lockdown and fire ENCOUNTER_END
    setLockdown(false)
    _G.hasanysecretvalues = function()
      return false
    end

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps(EventBridge))

    assert(Bootstrap.lockdown.active == false, "encounter_end: lockdown.active should become false")
    assert(Bootstrap.lockdown.source == "ENCOUNTER_END", "encounter_end: source should be ENCOUNTER_END")
    assert(_G._wmSuspended == nil, "encounter_end: _wmSuspended should be cleared")
    assert(#runtime.secretDeferredQueue == 0, "encounter_end: queue should be drained")

    _G.C_ChatInfo, _G._wmSuspended, _G.hasanysecretvalues = savedChatInfo, savedSuspended, savedHas
  end

  -- -------------------------------------------------------------------------
  -- test_handle_challenge_mode_start_suspends_and_sets_source
  -- -------------------------------------------------------------------------
  do
    local savedChatInfo = _G.C_ChatInfo
    setLockdown(true)

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local LockdownState = reloadLockdownState()

    local suspendCalls = 0
    local runtime = makeRuntime()
    runtime.suspend = function()
      suspendCalls = suspendCalls + 1
    end
    runtime.resume = function() end

    local Bootstrap = { runtime = runtime }
    LockdownState.Initialize(Bootstrap)

    LifecycleHandlers.Handle(Bootstrap, "CHALLENGE_MODE_START", makeDeps(EventBridge))

    assert(Bootstrap.lockdown.active == true, "challenge_mode_start: lockdown.active should become true")
    assert(Bootstrap.lockdown.source == "CHALLENGE_MODE_START", "challenge_mode_start: source set")
    assert(suspendCalls == 1, "challenge_mode_start: runtime.suspend should be called once")

    _G.C_ChatInfo = savedChatInfo
  end

  -- -------------------------------------------------------------------------
  -- test_handle_challenge_mode_completed_resumes_and_syncs
  -- -------------------------------------------------------------------------
  do
    local savedChatInfo = _G.C_ChatInfo
    setLockdown(false)

    local EventBridge = reloadEventBridge()
    local LifecycleHandlers = reloadLifecycleHandlers()
    local LockdownState = reloadLockdownState()

    local resumeCalls = 0
    local runtime = makeRuntime()
    runtime.suspend = function() end
    runtime.resume = function()
      resumeCalls = resumeCalls + 1
    end

    local Bootstrap = { runtime = runtime }
    LockdownState.Initialize(Bootstrap)
    Bootstrap.lockdown.active = true
    Bootstrap.lockdown.source = "CHALLENGE_MODE_START"

    LifecycleHandlers.Handle(Bootstrap, "CHALLENGE_MODE_COMPLETED", makeDeps(EventBridge))

    assert(Bootstrap.lockdown.active == false, "challenge_mode_completed: lockdown.active should clear")
    assert(Bootstrap.lockdown.source == "CHALLENGE_MODE_COMPLETED", "challenge_mode_completed: source set")
    assert(resumeCalls == 1, "challenge_mode_completed: runtime.resume should be called once")

    _G.C_ChatInfo = savedChatInfo
  end

  _G.C_Timer = savedCTimer
end
