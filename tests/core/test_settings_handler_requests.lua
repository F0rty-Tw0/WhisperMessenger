local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

-- Toggling the Requests inbox shows/hides the Requests tab; turning it off
-- while on that tab moves the player back to Whispers.

local function makeRuntime(tabMode)
  local calls = { setTabMode = {}, visibility = 0, refreshWindow = 0 }
  local runtime = {
    store = { config = {} },
    window = {
      getTabMode = function()
        return tabMode
      end,
      setTabMode = function(mode)
        calls.setTabMode[#calls.setTabMode + 1] = mode
      end,
      refreshTabToggleVisibility = function()
        calls.visibility = calls.visibility + 1
      end,
    },
    refreshWindow = function()
      calls.refreshWindow = calls.refreshWindow + 1
    end,
  }
  return runtime, calls
end

return function()
  -- test_enabling_shows_the_tab_and_refreshes
  do
    local runtime, calls = makeRuntime("whispers")
    local settings = {}
    SettingsHandler.Create({ runtime = runtime, accountSettings = settings })("requestsInbox", true)
    assert(settings.requestsInbox == true, "setting persisted")
    assert(calls.visibility == 1 and calls.refreshWindow == 1, "tab shown and lists/badges refreshed")
    assert(#calls.setTabMode == 0, "tab left alone when enabling")
  end

  -- test_disabling_on_requests_tab_returns_to_whispers
  do
    local runtime, calls = makeRuntime("requests")
    SettingsHandler.Create({ runtime = runtime, accountSettings = { requestsInbox = true } })("requestsInbox", false)
    assert(calls.setTabMode[1] == "whispers", "back to Whispers")
    assert(calls.visibility == 1 and calls.refreshWindow == 1, "tab hidden and refreshed")
  end

  -- test_disabling_elsewhere_keeps_the_tab
  do
    local runtime, calls = makeRuntime("groups")
    SettingsHandler.Create({ runtime = runtime, accountSettings = {} })("requestsInbox", false)
    assert(#calls.setTabMode == 0, "Groups tab kept")
  end
end
