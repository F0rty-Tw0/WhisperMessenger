-- A live whisper asks the runtime's next-frame refresh for its window
-- redraw, so several whispers (or parts of one long whisper) landing in one
-- frame redraw the window once. Without that refresh the caller's callback
-- runs at once, as before.

require("tests.helpers.fake_ui")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

local function newRuntime()
  local h = { scheduled = {}, direct = {} }
  h.runtime = {
    store = { conversations = {}, config = {} },
    localProfileId = "me",
    now = function()
      return 100
    end,
    availabilityByGUID = {},
    pendingOutgoing = {},
    accountState = { settings = {} },
  }
  h.refreshWindow = function(key)
    h.direct[#h.direct + 1] = key
  end
  return h
end

local function withCoalescer(h)
  h.lines = {}
  h.runtime.scheduleWhisperRefresh = function(key, line)
    h.scheduled[#h.scheduled + 1] = key
    h.lines[#h.lines + 1] = line
  end
  return h
end

local function route(h, eventName, text)
  return EventBridge.RouteLiveEvent(h.runtime, h.refreshWindow, eventName, text, "Arthas", "", "", "", "", "", "", "", "", 1, "Player-1-ABC")
end

return function()
  local savedGetCVar = _G.GetCVar
  local savedSetCVar = _G.SetCVar
  rawset(_G, "GetCVar", function()
    return "1"
  end)
  rawset(_G, "SetCVar", function() end)

  -- test_incoming_whisper_refresh_goes_through_the_next_frame_refresh
  do
    local h = withCoalescer(newRuntime())
    local result = route(h, "CHAT_MSG_WHISPER", "hello")
    assert(result and result.conversationKey, "the whisper is stored")
    assert(#h.direct == 0, "the window must not redraw inside the event, got " .. #h.direct)
    assert(#h.scheduled == 1 and h.scheduled[1] == result.conversationKey, "the next-frame refresh gets the whisper's key")
  end

  -- test_next_frame_refresh_gets_the_whisper_line
  do
    local h = withCoalescer(newRuntime())
    route(h, "CHAT_MSG_WHISPER", "hello")
    local line = h.lines[1]
    assert(line and line.eventName == "CHAT_MSG_WHISPER", "the refresh gets the line's event")
    assert(line.text == "hello" and line.name == "Arthas", "the refresh gets the line's text and sender")
  end

  -- test_parts_of_one_long_whisper_each_ask_the_next_frame_refresh
  do
    local h = withCoalescer(newRuntime())
    route(h, "CHAT_MSG_WHISPER", "part one")
    route(h, "CHAT_MSG_WHISPER", "part two")
    route(h, "CHAT_MSG_WHISPER", "part three")
    assert(#h.direct == 0, "no part redraws the window at once")
    assert(#h.scheduled == 3, "every part is handed to the next-frame refresh, got " .. #h.scheduled)
  end

  -- test_outgoing_whisper_refresh_goes_through_the_next_frame_refresh
  do
    local h = withCoalescer(newRuntime())
    local result = route(h, "CHAT_MSG_WHISPER_INFORM", "hi back")
    assert(result and result.conversationKey, "the sent whisper is stored")
    assert(#h.direct == 0 and #h.scheduled == 1, "the sent whisper's echo redraws on the next frame")
  end

  -- test_whisper_refreshes_at_once_without_next_frame_refresh
  do
    local h = newRuntime()
    local result = route(h, "CHAT_MSG_WHISPER", "hello")
    assert(#h.direct == 1 and h.direct[1] == result.conversationKey, "no next-frame refresh -> the callback runs at once")
  end

  -- test_no_refresh_callback_asks_for_no_refresh
  do
    local h = withCoalescer(newRuntime())
    EventBridge.RouteLiveEvent(h.runtime, nil, "CHAT_MSG_WHISPER", "hello", "Arthas", "", "", "", "", "", "", "", "", 1, "Player-1-ABC")
    assert(#h.scheduled == 0, "a caller without a refresh callback gets no refresh")
  end

  rawset(_G, "GetCVar", savedGetCVar)
  rawset(_G, "SetCVar", savedSetCVar)
end
