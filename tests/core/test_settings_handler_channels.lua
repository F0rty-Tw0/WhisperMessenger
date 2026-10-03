local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

-- Picking channels on the Chats page persists the new table and refreshes
-- the window so channel chats appear or disappear right away.
return function()
  -- test_enabled_channels_change_refreshes_the_window
  do
    local refreshes = 0
    local runtime = {
      store = { config = {} },
      refreshWindow = function()
        refreshes = refreshes + 1
      end,
    }
    local settings = {}
    local nextChannels = { trade = true }
    SettingsHandler.Create({ runtime = runtime, accountSettings = settings })("enabledChannels", nextChannels)
    assert(settings.enabledChannels == nextChannels, "setting persisted")
    assert(refreshes == 1, "window refreshed once, got " .. refreshes)
  end
end
