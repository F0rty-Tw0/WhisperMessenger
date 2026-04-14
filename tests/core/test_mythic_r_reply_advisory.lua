local MythicSuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")

return function()
  local function makeBootstrapAndBridge()
    return {
      _loadFrame = {},
      unregisterChatFilters = function() end,
      registerChatFilters = function() end,
    }, {
      UnregisterLiveEvents = function() end,
      UnregisterSuspendableLifecycleEvents = function() end,
      RegisterLiveEvents = function() end,
      RegisterSuspendableLifecycleEvents = function() end,
    }
  end

  -- -----------------------------------------------------------------------
  -- test_suspend_warns_about_r_reply_when_hide_from_default_chat_on
  -- -----------------------------------------------------------------------
  -- When user enters Mythic+ with hideFromDefaultChat=true, the chat filter
  -- chain has already tainted Blizzard's chatEditLastTell from pre-M+
  -- whispers. /r and R-key will crash. Surface that in chat on mythic entry
  -- so the user knows to use /wr.
  do
    local runtime = {
      accountState = { settings = { hideFromDefaultChat = true } },
    }
    local Bootstrap, EventBridge = makeBootstrapAndBridge()

    local printed = {}
    MythicSuspendController.Attach(runtime, {
      Bootstrap = Bootstrap,
      isWindowVisible = function()
        return false
      end,
      setWindowVisible = function() end,
      refreshWindow = function() end,
      getEventBridge = function()
        return EventBridge
      end,
      print = function(msg)
        table.insert(printed, msg)
      end,
    })

    runtime.suspend()

    local warned = false
    for _, msg in ipairs(printed) do
      if type(msg) == "string" and string.find(msg, "/wr", 1, true) then
        warned = true
        break
      end
    end
    assert(warned, "suspend must print a /wr advisory when hideFromDefaultChat=true")
  end

  -- -----------------------------------------------------------------------
  -- test_suspend_does_not_warn_when_hide_from_default_chat_off
  -- -----------------------------------------------------------------------
  do
    local runtime = {
      accountState = { settings = { hideFromDefaultChat = false } },
    }
    local Bootstrap, EventBridge = makeBootstrapAndBridge()

    local printed = {}
    MythicSuspendController.Attach(runtime, {
      Bootstrap = Bootstrap,
      isWindowVisible = function()
        return false
      end,
      setWindowVisible = function() end,
      refreshWindow = function() end,
      getEventBridge = function()
        return EventBridge
      end,
      print = function(msg)
        table.insert(printed, msg)
      end,
    })

    runtime.suspend()

    for _, msg in ipairs(printed) do
      if type(msg) == "string" and string.find(msg, "/wr", 1, true) then
        error("suspend must NOT print /wr advisory when hideFromDefaultChat=false")
      end
    end
  end
end
