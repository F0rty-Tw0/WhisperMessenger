local FilterApi = require("WhisperMessenger.Core.Bootstrap.ChatFilters.FilterApi")

local function withGlobals(globals, fn)
  local names = { "ChatFrameUtil", "ChatFrame_AddMessageEventFilter", "ChatFrame_RemoveMessageEventFilter", "securecall" }
  local saved = {}
  for _, name in ipairs(names) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, globals[name])
  end
  local ok, err = pcall(fn)
  for _, name in ipairs(names) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return function()
  -- test_add_prefers_chat_frame_util
  withGlobals({
    ChatFrameUtil = {
      AddMessageEventFilter = function(event, fn)
        _G.__wmUtilAdded = { event = event, fn = fn }
      end,
    },
    ChatFrame_AddMessageEventFilter = function()
      error("deprecated global must not be used when ChatFrameUtil exists")
    end,
  }, function()
    local filter = function() end
    assert(FilterApi.Add("CHAT_MSG_SAY", filter) == true, "Add should report success")
    assert(_G.__wmUtilAdded.event == "CHAT_MSG_SAY", "event forwarded to ChatFrameUtil")
    assert(_G.__wmUtilAdded.fn == filter, "filter forwarded to ChatFrameUtil")
  end)
  rawset(_G, "__wmUtilAdded", nil)

  -- test_remove_falls_back_to_global
  withGlobals({
    ChatFrame_RemoveMessageEventFilter = function(event)
      _G.__wmRemoved = event
    end,
  }, function()
    assert(FilterApi.Remove("CHAT_MSG_SAY", function() end) == true, "Remove should report success")
    assert(_G.__wmRemoved == "CHAT_MSG_SAY", "global remove should be called")
  end)
  rawset(_G, "__wmRemoved", nil)

  -- test_routes_through_securecall
  withGlobals({
    ChatFrameUtil = { AddMessageEventFilter = function() end },
    securecall = function(fn, ...)
      _G.__wmSecureTarget = fn
      return fn(...)
    end,
  }, function()
    FilterApi.Add("CHAT_MSG_SAY", function() end)
    assert(_G.__wmSecureTarget == _G.ChatFrameUtil.AddMessageEventFilter, "securecall must wrap the Blizzard function")
  end)
  rawset(_G, "__wmSecureTarget", nil)

  -- test_returns_false_when_no_api
  withGlobals({}, function()
    assert(FilterApi.IsAvailable() == false, "no API means unavailable")
    assert(FilterApi.Add("CHAT_MSG_SAY", function() end) == false, "Add should fail without an API")
    assert(FilterApi.Remove("CHAT_MSG_SAY", function() end) == false, "Remove should fail without an API")
  end)

  -- test_is_available_with_either_api
  withGlobals({ ChatFrameUtil = { AddMessageEventFilter = function() end } }, function()
    assert(FilterApi.IsAvailable() == true, "ChatFrameUtil makes the API available")
  end)
  withGlobals({ ChatFrame_AddMessageEventFilter = function() end }, function()
    assert(FilterApi.IsAvailable() == true, "the global makes the API available")
  end)
end
