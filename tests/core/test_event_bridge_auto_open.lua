local FakeUI = require("tests.helpers.fake_ui")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

return function()
  -- -----------------------------------------------------------------------
  -- Helpers
  -- -----------------------------------------------------------------------
  local function stubGlobals()
    rawset(_G, "PlaySound", function() end)
    rawset(_G, "GetCVar", function()
      return "1"
    end)
    rawset(_G, "SetCVar", function() end)
    _G.C_Timer = {
      After = function(_delay, fn)
        fn()
      end,
    }
  end

  local function cleanupGlobals()
    rawset(_G, "PlaySound", nil)
    rawset(_G, "GetCVar", nil)
    rawset(_G, "SetCVar", nil)
    _G.C_Timer = nil
    rawset(_G, "InCombatLockdown", nil)
  end

  local function makeRuntime(settings)
    return {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      accountState = { settings = settings or {} },
    }
  end

  local WHISPER_ARGS = {
    "hello",
    "Arthas",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    1,
    "Player-1-ABC",
  }

  -- -----------------------------------------------------------------------
  -- test_auto_open_called_on_incoming_whisper_when_enabled
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local autoOpenCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = true })
    runtime.onAutoOpen = function(conversationKey)
      autoOpenCalls[#autoOpenCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(WHISPER_ARGS))

    assert(#autoOpenCalls == 1, "test_auto_open_called_on_incoming_whisper: expected 1 call, got " .. #autoOpenCalls)
    assert(autoOpenCalls[1] ~= nil, "test_auto_open_called_on_incoming_whisper: conversationKey should not be nil")
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_not_called_when_setting_disabled
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local autoOpenCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = false })
    runtime.onAutoOpen = function(conversationKey)
      autoOpenCalls[#autoOpenCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(WHISPER_ARGS))

    assert(#autoOpenCalls == 0, "test_auto_open_not_called_when_disabled: expected 0 calls, got " .. #autoOpenCalls)
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_not_called_during_combat
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return true
    end)

    local autoOpenCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = true })
    runtime.onAutoOpen = function(conversationKey)
      autoOpenCalls[#autoOpenCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(WHISPER_ARGS))

    assert(#autoOpenCalls == 0, "test_auto_open_not_called_during_combat: expected 0 calls, got " .. #autoOpenCalls)
    -- But lastIncomingWhisperKey should still be tracked for reply after combat
    assert(
      runtime.lastIncomingWhisperKey ~= nil,
      "test_auto_open_not_called_during_combat: lastIncomingWhisperKey should be set even in combat"
    )
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_incoming_not_called_on_outgoing_whisper
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local autoOpenCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = true })
    runtime.pendingOutgoing = {}
    runtime.onAutoOpen = function(conversationKey)
      autoOpenCalls[#autoOpenCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER_INFORM", table.unpack(WHISPER_ARGS))

    assert(
      #autoOpenCalls == 0,
      "test_auto_open_incoming_not_called_on_outgoing: expected 0 onAutoOpen calls, got " .. #autoOpenCalls
    )
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_outgoing_called_on_whisper_inform
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local outgoingCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = true })
    runtime.pendingOutgoing = {}
    runtime.onAutoOpenOutgoing = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER_INFORM", table.unpack(WHISPER_ARGS))

    assert(#outgoingCalls == 1, "test_auto_open_outgoing_on_inform: expected 1 call, got " .. #outgoingCalls)
    assert(outgoingCalls[1] ~= nil, "test_auto_open_outgoing_on_inform: conversationKey should not be nil")
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_outgoing_not_called_for_tracked_pending_send
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local outgoingCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = true })
    runtime.pendingOutgoing = {
      ["wow::WOW::arthas-area52"] = {
        {
          text = "hello",
          createdAt = 99,
          channel = "WOW",
          guid = "Player-1-ABC",
          displayName = "Arthas-Area52",
        },
      },
    }
    runtime.onAutoOpenOutgoing = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER_INFORM", table.unpack(WHISPER_ARGS))

    assert(
      #outgoingCalls == 0,
      "test_auto_open_outgoing_pending_send: expected 0 calls for tracked pending send, got " .. #outgoingCalls
    )
    local pending = runtime.pendingOutgoing["wow::WOW::arthas-area52"]
    assert(
      pending ~= nil and #pending == 0,
      "test_auto_open_outgoing_pending_send: expected pending send to be consumed"
    )
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_outgoing_called_on_bnet_inform
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local outgoingCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = true })
    runtime.pendingOutgoing = {}
    runtime.onAutoOpenOutgoing = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_BN_WHISPER_INFORM",
      "hello",
      "Friend#1234",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      1,
      "Player-1-DEF",
      42
    )

    assert(#outgoingCalls == 1, "test_auto_open_outgoing_on_bnet_inform: expected 1 call, got " .. #outgoingCalls)
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_outgoing_not_called_during_combat
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return true
    end)

    local outgoingCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = true })
    runtime.pendingOutgoing = {}
    runtime.onAutoOpenOutgoing = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER_INFORM", table.unpack(WHISPER_ARGS))

    assert(#outgoingCalls == 0, "test_auto_open_outgoing_combat: expected 0 calls, got " .. #outgoingCalls)
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_outgoing_not_called_when_setting_disabled
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local outgoingCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = false })
    runtime.pendingOutgoing = {}
    runtime.onAutoOpenOutgoing = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER_INFORM", table.unpack(WHISPER_ARGS))

    assert(#outgoingCalls == 0, "test_auto_open_outgoing_disabled: expected 0 calls, got " .. #outgoingCalls)
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_called_on_bnet_whisper
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local autoOpenCalls = {}
    local runtime = makeRuntime({ autoOpenWindow = true })
    runtime.onAutoOpen = function(conversationKey)
      autoOpenCalls[#autoOpenCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_BN_WHISPER",
      "hello",
      "Friend#1234",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      1,
      "Player-1-DEF",
      42
    )

    assert(#autoOpenCalls == 1, "test_auto_open_called_on_bnet_whisper: expected 1 call, got " .. #autoOpenCalls)
    cleanupGlobals()
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_not_called_when_no_callback
  -- -----------------------------------------------------------------------
  do
    stubGlobals()
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local runtime = makeRuntime({ autoOpenWindow = true })
    -- No onAutoOpen callback set — should not error
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(WHISPER_ARGS))

    -- If we get here without error, the test passes
    cleanupGlobals()
  end
end
