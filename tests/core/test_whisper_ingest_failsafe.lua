local ChatFilters = require("WhisperMessenger.Core.Bootstrap.ChatFilters")
local Failsafe = require("WhisperMessenger.Core.Bootstrap.WhisperIngestFailsafe")

-- When our whisper ingest throws, the always-true chat filters have already
-- hidden the line from the default chat: the failsafe echoes it, reports the
-- error, and after repeated errors stops hiding whispers for the session.
local PREFIX = "|cffffd100Whisper Messenger:|r "
local STOPPED = PREFIX .. "WhisperMessenger hit repeated errors and stopped hiding whispers from chat until you /reload."
local SECRET = "<secret>"

local function setup(settings)
  local saved = {
    util = rawget(_G, "ChatFrameUtil"),
    chat = rawget(_G, "DEFAULT_CHAT_FRAME"),
    geterrorhandler = rawget(_G, "geterrorhandler"),
    issecretvalue = rawget(_G, "issecretvalue"),
  }
  local active = {}
  rawset(_G, "ChatFrameUtil", {
    AddMessageEventFilter = function(event, fn)
      active[event] = fn
    end,
    RemoveMessageEventFilter = function(event, fn)
      if active[event] == fn then
        active[event] = nil
      end
    end,
  })
  local printed, reported = {}, {}
  rawset(_G, "DEFAULT_CHAT_FRAME", {
    AddMessage = function(_self, text)
      printed[#printed + 1] = text
    end,
  })
  rawset(_G, "geterrorhandler", function()
    return function(err)
      reported[#reported + 1] = err
    end
  end)
  rawset(_G, "issecretvalue", function(value)
    return value == SECRET
  end)

  local accountState = { settings = settings or { hideFromDefaultChat = true } }
  local runtime = { accountState = accountState, refreshWindow = function() end }
  local Bootstrap = {}
  ChatFilters.Configure(Bootstrap, accountState, nil)
  Bootstrap.syncChatFilters()

  local routed = {}
  local bridge = { fail = true }
  bridge.RouteLiveEvent = function(routeRuntime, refreshWindow, eventName, text, sender)
    routed[#routed + 1] = { runtime = routeRuntime, refreshWindow = refreshWindow, eventName = eventName, text = text, sender = sender }
    if bridge.fail then
      error("ingest broke")
    end
    return "stored"
  end

  local function route(eventName, text, sender)
    return Failsafe.RouteLiveEvent(Bootstrap, bridge, runtime, runtime.refreshWindow, eventName, text, sender)
  end

  local function restore()
    for key, value in pairs(saved) do
      local globalKey = key == "util" and "ChatFrameUtil" or key == "chat" and "DEFAULT_CHAT_FRAME" or key
      rawset(_G, globalKey, value)
    end
  end

  return {
    Bootstrap = Bootstrap,
    bridge = bridge,
    route = route,
    runtime = runtime,
    active = active,
    printed = printed,
    reported = reported,
    routed = routed,
    restore = restore,
  }
end

local function run(fn)
  local ctx = setup()
  local ok, err = pcall(fn, ctx)
  ctx.restore()
  assert(ok, err)
end

local function countOf(list, value)
  local count = 0
  for _, item in ipairs(list) do
    if item == value then
      count = count + 1
    end
  end
  return count
end

return function()
  -- test_normal_whisper_routes_unchanged
  run(function(ctx)
    ctx.bridge.fail = false
    local result = ctx.route("CHAT_MSG_WHISPER", "hi", "Bob-Realm")
    assert(result == "stored", "expected the bridge result passed through, got " .. tostring(result))
    assert(#ctx.routed == 1, "expected one route call")
    local call = ctx.routed[1]
    assert(call.runtime == ctx.runtime and call.refreshWindow == ctx.runtime.refreshWindow, "expected runtime and refresh passed through")
    assert(call.eventName == "CHAT_MSG_WHISPER" and call.text == "hi" and call.sender == "Bob-Realm", "expected event args passed through")
    assert(#ctx.printed == 0, "expected no chat echo on success")
    assert(#ctx.reported == 0, "expected no error report on success")
  end)

  -- test_ingest_error_reports_to_error_handler
  run(function(ctx)
    ctx.route("CHAT_MSG_WHISPER", "hi", "Bob-Realm")
    assert(#ctx.reported == 1, "expected the error handed to the error handler")
    assert(string.find(tostring(ctx.reported[1]), "ingest broke", 1, true), "expected the original error message, got " .. tostring(ctx.reported[1]))
  end)

  -- test_ingest_error_echoes_hidden_incoming_whisper
  run(function(ctx)
    ctx.route("CHAT_MSG_WHISPER", "hi", "Bob-Realm")
    assert(ctx.printed[1] == PREFIX .. "Couldn't store a whisper from Bob-Realm: hi", "unexpected echo: " .. tostring(ctx.printed[1]))
  end)

  -- test_ingest_error_echoes_hidden_outgoing_whisper
  run(function(ctx)
    ctx.route("CHAT_MSG_BN_WHISPER_INFORM", "see you", "Alice")
    assert(ctx.printed[1] == PREFIX .. "Couldn't store a whisper to Alice: see you", "unexpected echo: " .. tostring(ctx.printed[1]))
  end)

  -- test_no_echo_for_secret_text
  run(function(ctx)
    ctx.route("CHAT_MSG_WHISPER", SECRET, "Bob-Realm")
    assert(#ctx.printed == 0, "expected no echo of a secret value")
    assert(#ctx.reported == 1, "expected the error still reported")
  end)

  -- test_no_echo_for_secret_sender
  run(function(ctx)
    ctx.route("CHAT_MSG_WHISPER", "hi", SECRET)
    assert(#ctx.printed == 0, "expected no echo of a secret sender")
  end)

  -- test_no_echo_when_whispers_are_not_hidden
  run(function(ctx)
    ctx.Bootstrap.unregisterChatFilters()
    ctx.route("CHAT_MSG_WHISPER", "hi", "Bob-Realm")
    assert(#ctx.printed == 0, "expected no echo when the game chat already shows the whisper")
    assert(#ctx.reported == 1, "expected the error still reported")
  end)

  -- test_third_error_stops_hiding_whispers_and_notifies_once
  run(function(ctx)
    ctx.route("CHAT_MSG_WHISPER", "one", "Bob-Realm")
    ctx.route("CHAT_MSG_WHISPER", "two", "Bob-Realm")
    assert(ctx.active.CHAT_MSG_WHISPER ~= nil, "expected whispers still hidden after two errors")
    assert(countOf(ctx.printed, STOPPED) == 0, "expected no notice before the third error")
    ctx.route("CHAT_MSG_WHISPER", "three", "Bob-Realm")
    for _, event in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }) do
      assert(ctx.active[event] == nil, "expected " .. event .. " filter removed after the third error")
    end
    assert(ctx.printed[3] == PREFIX .. "Couldn't store a whisper from Bob-Realm: three", "expected the third whisper echoed too")
    assert(countOf(ctx.printed, STOPPED) == 1, "expected the stop notice after the third error")
    ctx.route("CHAT_MSG_WHISPER", "four", "Bob-Realm")
    assert(countOf(ctx.printed, STOPPED) == 1, "expected the stop notice printed only once")
    assert(#ctx.reported == 4, "expected every error still reported")
  end)

  -- test_tripped_failsafe_keeps_whisper_filters_off_for_the_session
  run(function(ctx)
    for _ = 1, 3 do
      ctx.route("CHAT_MSG_WHISPER", "x", "Bob-Realm")
    end
    ctx.Bootstrap.syncChatFilters()
    assert(ctx.active.CHAT_MSG_WHISPER == nil, "expected sync to keep whisper filters off")
    ctx.Bootstrap.registerChatFilters()
    assert(ctx.active.CHAT_MSG_WHISPER == nil, "expected a direct register (M+ resume) to keep whisper filters off")
  end)

  -- test_non_whisper_event_errors_propagate
  run(function(ctx)
    local ok = pcall(ctx.route, "CHAT_MSG_AFK", "brb", "Bob-Realm")
    assert(not ok, "expected a non-whisper event error to propagate as before")
    assert(#ctx.reported == 0 and #ctx.printed == 0, "expected no failsafe handling for non-whisper events")
  end)
end
