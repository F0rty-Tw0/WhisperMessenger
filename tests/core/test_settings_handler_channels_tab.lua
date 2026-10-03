local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

-- Ticking channels shows/hides the Channels tab; unticking the last one
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
  -- test_ticking_a_channel_shows_the_tab
  do
    local runtime, calls = makeRuntime("whispers")
    SettingsHandler.Create({ runtime = runtime, accountSettings = {} })("enabledChannels", { trade = true })
    assert(calls.visibility == 1, "tab visibility re-evaluated")
    assert(calls.refreshWindow == 1, "lists and badges refreshed once")
    assert(#calls.setTabMode == 0, "tab left alone when ticking")
  end

  -- test_unticking_the_last_channel_on_channels_tab_returns_to_whispers
  do
    local runtime, calls = makeRuntime("channels")
    SettingsHandler.Create({ runtime = runtime, accountSettings = {} })("enabledChannels", { trade = false })
    assert(calls.setTabMode[1] == "whispers", "back to Whispers")
    assert(calls.visibility == 1, "tab hidden")
  end

  -- test_unticking_one_of_several_keeps_the_channels_tab
  do
    local runtime, calls = makeRuntime("channels")
    SettingsHandler.Create({ runtime = runtime, accountSettings = {} })("enabledChannels", { trade = false, general = true })
    assert(#calls.setTabMode == 0, "Channels tab kept while a channel is still ticked")
  end
end
