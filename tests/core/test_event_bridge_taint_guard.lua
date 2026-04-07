-- Tests for the defer-and-sanitize taint guard added to EventBridge.
-- Each do-block is an isolated scenario with explicit global setup/teardown.

local FakeUI = require("tests.helpers.fake_ui")
local Store = require("WhisperMessenger.Model.ConversationStore")

-- Force a fresh require of EventBridge (and SecretTaintGuard) each block so
-- module-level upvalues (FlavorCompat globals) are re-probed correctly.
local EB_KEY = "WhisperMessenger.Core.Bootstrap.EventBridge"
local STG_KEY = "WhisperMessenger.Core.Bootstrap.SecretTaintGuard"
local FC_KEY = "WhisperMessenger.Core.FlavorCompat"

local function reloadEventBridge()
  package.loaded[EB_KEY] = nil
  package.loaded[STG_KEY] = nil
  -- FlavorCompat probes globals at call time (not load time), so no need to
  -- reload it — but clear it anyway to be safe.
  package.loaded[FC_KEY] = nil
  return require(EB_KEY)
end

local function makeRuntime()
  return {
    store = Store.New({ maxMessagesPerConversation = 10 }),
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

-- Standard 12-arg CHAT_MSG_WHISPER payload (text, sender, ..., lineID, guid)
local function whisperArgs(text, sender)
  return {
    text or "hello",
    sender or "Arthas-Area52",
    "", -- language
    "", -- channelString
    "", -- target
    "", -- flags
    "", -- unknown1
    0, -- channelNumber
    "", -- channelName
    0, -- unknown2
    1, -- lineID
    "Player-3676-0ABCDEF0", -- guid
  }
end

return function()
  -- -------------------------------------------------------------------------
  -- Test A: HasAnySecretValues=true triggers deferral
  -- -------------------------------------------------------------------------
  do
    local saved = _G.hasanysecretvalues
    _G.hasanysecretvalues = function(...)
      return true
    end

    local EventBridge = reloadEventBridge()
    local runtime = makeRuntime()
    local refreshCalled = false

    local args = whisperArgs("secret text", "Player-Realm")
    local result = EventBridge.RouteLiveEvent(runtime, function()
      refreshCalled = true
    end, "CHAT_MSG_WHISPER", table.unpack(args))

    assert(result == nil, "Test A: RouteLiveEvent should return nil when tainted, got: " .. tostring(result))
    assert(next(runtime.store.conversations) == nil, "Test A: no conversation should be created for tainted event")
    assert(type(runtime.secretDeferredQueue) == "table", "Test A: secretDeferredQueue should be a table")
    assert(
      #runtime.secretDeferredQueue == 1,
      "Test A: queue should have 1 item, got: " .. tostring(#(runtime.secretDeferredQueue or {}))
    )
    assert(
      runtime.secretDeferredQueue[1].eventName == "CHAT_MSG_WHISPER",
      "Test A: queued item should preserve eventName"
    )

    _G.hasanysecretvalues = saved
  end

  -- -------------------------------------------------------------------------
  -- Test B: HasAnySecretValues=false routes normally
  -- -------------------------------------------------------------------------
  do
    local saved = _G.hasanysecretvalues
    _G.hasanysecretvalues = function(...)
      return false
    end

    local EventBridge = reloadEventBridge()
    local runtime = makeRuntime()

    local args = whisperArgs("hello", "Arthas-Area52")
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(args))

    assert(
      runtime.secretDeferredQueue == nil or #runtime.secretDeferredQueue == 0,
      "Test B: queue should be empty when args are clean"
    )
    local convCount = 0
    for _ in pairs(runtime.store.conversations) do
      convCount = convCount + 1
    end
    assert(convCount == 1, "Test B: conversation should be created for clean event, got count=" .. convCount)

    _G.hasanysecretvalues = saved
  end

  -- -------------------------------------------------------------------------
  -- Test C: Drain on lockdown clear processes queued items and returns count
  -- -------------------------------------------------------------------------
  do
    local savedHas = _G.hasanysecretvalues
    local savedIsSecret = _G.issecretvalue
    local savedChatInfo = _G.C_ChatInfo

    -- Phase 1: enqueue 2 items with taint active
    _G.hasanysecretvalues = function(...)
      return true
    end
    _G.issecretvalue = function(v)
      -- treat the sender arg (position 2) as tainted; everything else clean
      return v == "tainted-sender"
    end

    local EventBridge = reloadEventBridge()
    local runtime = makeRuntime()

    local args1 = whisperArgs("msg1", "tainted-sender")
    local args2 = whisperArgs("msg2", "tainted-sender")
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(args1))
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(args2))

    assert(#runtime.secretDeferredQueue == 2, "Test C: expected 2 queued items before drain")

    -- Phase 2: clear lockdown and drain
    _G.hasanysecretvalues = function(...)
      return false
    end
    _G.C_ChatInfo = {
      InChatMessagingLockdown = function()
        return false
      end,
    }

    local count = EventBridge.DrainSecretDeferredQueue(runtime, nil)

    assert(count == 2, "Test C: DrainSecretDeferredQueue should return 2, got: " .. tostring(count))
    assert(
      #runtime.secretDeferredQueue == 0,
      "Test C: queue should be empty after drain, got: " .. #runtime.secretDeferredQueue
    )

    _G.hasanysecretvalues = savedHas
    _G.issecretvalue = savedIsSecret
    _G.C_ChatInfo = savedChatInfo
  end

  -- -------------------------------------------------------------------------
  -- Test D: Drain bails while still locked
  -- -------------------------------------------------------------------------
  do
    local savedHas = _G.hasanysecretvalues
    local savedChatInfo = _G.C_ChatInfo

    -- Enqueue 1 item
    _G.hasanysecretvalues = function(...)
      return true
    end

    local EventBridge = reloadEventBridge()
    local runtime = makeRuntime()

    local args = whisperArgs("msg", "tainted-sender")
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(args))
    assert(#runtime.secretDeferredQueue == 1, "Test D: expected 1 queued item before drain attempt")

    -- Lockdown still active
    _G.C_ChatInfo = {
      InChatMessagingLockdown = function()
        return true
      end,
    }
    -- hasanysecretvalues doesn't matter for drain, but reset to avoid side effects
    _G.hasanysecretvalues = function(...)
      return false
    end

    local count = EventBridge.DrainSecretDeferredQueue(runtime, nil)

    assert(count == 0, "Test D: drain should return 0 while locked, got: " .. tostring(count))
    assert(
      #runtime.secretDeferredQueue == 1,
      "Test D: queue should still have 1 item while locked, got: " .. #runtime.secretDeferredQueue
    )

    _G.hasanysecretvalues = savedHas
    _G.C_ChatInfo = savedChatInfo
  end
end
