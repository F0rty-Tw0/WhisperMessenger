local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- Auto-open behavior splits across two callbacks:
--   * onAutoOpen          - incoming whispers (CHAT_MSG_WHISPER, CHAT_MSG_BN_WHISPER)
--   * onAutoOpenOutgoing  - outgoing replies  (CHAT_MSG_WHISPER_INFORM, CHAT_MSG_BN_WHISPER_INFORM)
--
-- Each callback is gated by:
--   * its own setting (autoOpenIncoming / autoOpenOutgoing)
--   * combat lockdown (InCombatLockdown == true suppresses both)
--   * for outgoing: tracked pending sends are silent (the user just hit send,
--     no need to surface the window again).

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

local BNET_ARGS = {
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
  42,
}

-- Stand up a minimal runtime + global stubs and run a single RouteLiveEvent
-- call. Callers see only what they care about: the runtime, the recorded
-- callback args, and a `dispatch` they can fire (defaulting to one
-- CHAT_MSG_WHISPER for ergonomics).
local function makeScenario(opts)
  opts = opts or {}
  local settings = opts.settings or { autoOpenIncoming = true, autoOpenOutgoing = true }
  local inCombat = opts.inCombat == true

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
  rawset(_G, "InCombatLockdown", function()
    return inCombat
  end)

  local runtime = {
    store = { conversations = {}, config = {} },
    localProfileId = "me",
    now = function()
      return 100
    end,
    availabilityByGUID = {},
    accountState = { settings = settings },
    pendingOutgoing = opts.pendingOutgoing or {},
  }

  local incomingCalls = {}
  local outgoingCalls = {}
  if not opts.skipIncomingCallback then
    runtime.onAutoOpen = function(conversationKey)
      incomingCalls[#incomingCalls + 1] = conversationKey
    end
  end
  if not opts.skipOutgoingCallback then
    runtime.onAutoOpenOutgoing = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
    end
  end

  return {
    runtime = runtime,
    incomingCalls = incomingCalls,
    outgoingCalls = outgoingCalls,
    dispatch = function(eventName, args)
      EventBridge.RouteLiveEvent(runtime, nil, eventName or "CHAT_MSG_WHISPER", table.unpack(args or WHISPER_ARGS))
    end,
  }
end

local function teardown()
  rawset(_G, "PlaySound", nil)
  rawset(_G, "GetCVar", nil)
  rawset(_G, "SetCVar", nil)
  _G.C_Timer = nil
  rawset(_G, "InCombatLockdown", nil)
end

return function()
  -- Incoming whisper with both settings on -> onAutoOpen fires once.
  do
    local s = makeScenario()
    s.dispatch()
    assert(#s.incomingCalls == 1, "expected 1 incoming auto-open, got " .. #s.incomingCalls)
    assert(s.incomingCalls[1] ~= nil, "incoming auto-open should receive a conversationKey")
    teardown()
  end

  -- Both settings off -> onAutoOpen does not fire on incoming whisper.
  do
    local s = makeScenario({ settings = { autoOpenIncoming = false, autoOpenOutgoing = false } })
    s.dispatch()
    assert(#s.incomingCalls == 0, "expected no incoming auto-open when setting disabled")
    teardown()
  end

  -- Combat lockdown suppresses incoming auto-open but still records the
  -- conversation key so the user can /reply once combat ends.
  do
    local s = makeScenario({ inCombat = true })
    s.dispatch()
    assert(#s.incomingCalls == 0, "expected no incoming auto-open during combat")
    assert(s.runtime.lastIncomingWhisperKey ~= nil, "lastIncomingWhisperKey should be tracked even during combat")
    teardown()
  end

  -- Only-incoming-enabled does NOT fire onAutoOpen for OUTGOING messages.
  do
    local s = makeScenario({ settings = { autoOpenIncoming = true, autoOpenOutgoing = true } })
    s.dispatch("CHAT_MSG_WHISPER_INFORM")
    assert(#s.incomingCalls == 0, "outgoing inform should not invoke onAutoOpen")
    teardown()
  end

  -- Outgoing inform with both settings on -> onAutoOpenOutgoing fires once.
  do
    local s = makeScenario()
    s.dispatch("CHAT_MSG_WHISPER_INFORM")
    assert(#s.outgoingCalls == 1, "expected 1 outgoing auto-open, got " .. #s.outgoingCalls)
    teardown()
  end

  -- Outgoing inform that matches a tracked pending send is silent: the user
  -- just clicked send, no need to surface the window again. The pending send
  -- is also consumed.
  do
    local s = makeScenario({
      pendingOutgoing = {
        ["wow::WOW::arthas-area52"] = {
          {
            text = "hello",
            createdAt = 99,
            channel = "WOW",
            guid = "Player-1-ABC",
            displayName = "Arthas-Area52",
          },
        },
      },
    })
    s.dispatch("CHAT_MSG_WHISPER_INFORM")
    assert(#s.outgoingCalls == 0, "tracked pending send should suppress outgoing auto-open")
    local consumed = s.runtime.pendingOutgoing["wow::WOW::arthas-area52"]
    assert(consumed and #consumed == 0, "matched pending send should be consumed")
    teardown()
  end

  -- BNet outgoing inform also fires onAutoOpenOutgoing.
  do
    local s = makeScenario()
    s.dispatch("CHAT_MSG_BN_WHISPER_INFORM", BNET_ARGS)
    assert(#s.outgoingCalls == 1, "BNet outgoing inform should fire onAutoOpenOutgoing")
    teardown()
  end

  -- Combat lockdown also suppresses outgoing auto-open.
  do
    local s = makeScenario({ inCombat = true })
    s.dispatch("CHAT_MSG_WHISPER_INFORM")
    assert(#s.outgoingCalls == 0, "outgoing auto-open should be suppressed during combat")
    teardown()
  end

  -- Outgoing setting off -> outgoing inform is silent.
  do
    local s = makeScenario({ settings = { autoOpenIncoming = false, autoOpenOutgoing = false } })
    s.dispatch("CHAT_MSG_WHISPER_INFORM")
    assert(#s.outgoingCalls == 0, "outgoing auto-open should respect the setting")
    teardown()
  end

  -- Only-outgoing-enabled keeps incoming auto-open silent.
  do
    local s = makeScenario({ settings = { autoOpenIncoming = false, autoOpenOutgoing = true } })
    s.dispatch()
    assert(#s.incomingCalls == 0, "incoming should stay silent when only outgoing is enabled")
    teardown()
  end

  -- Incoming-only setting still fires the OUTGOING setting independently:
  -- this is a separate gate from the above (verifies they don't share state).
  do
    local s = makeScenario({ settings = { autoOpenIncoming = true, autoOpenOutgoing = false } })
    s.dispatch("CHAT_MSG_WHISPER_INFORM")
    assert(#s.outgoingCalls == 0, "outgoing should stay silent when only incoming is enabled")
    teardown()
  end

  -- BNet whisper triggers incoming auto-open.
  do
    local s = makeScenario()
    s.dispatch("CHAT_MSG_BN_WHISPER", BNET_ARGS)
    assert(#s.incomingCalls == 1, "BNet incoming whisper should trigger onAutoOpen")
    teardown()
  end

  -- No callbacks at all - dispatch must not error.
  do
    local s = makeScenario({ skipIncomingCallback = true, skipOutgoingCallback = true })
    local ok = pcall(s.dispatch)
    assert(ok, "RouteLiveEvent should not error when callbacks are absent")
    teardown()
  end
end
