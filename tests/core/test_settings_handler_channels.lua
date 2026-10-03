local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

-- Picking channels on the Chats page persists the new table and refreshes
-- the window so channel chats appear or disappear right away. Channel and
-- filter changes resync the game-chat filters.
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

  local function syncCounter()
    local counter = { syncs = 0 }
    counter.runtime = {
      store = { config = {} },
      syncChatFilters = function()
        counter.syncs = counter.syncs + 1
      end,
    }
    return counter
  end

  -- test_hide_channels_change_resyncs_chat_filters
  do
    local counter = syncCounter()
    SettingsHandler.Create({ runtime = counter.runtime, accountSettings = {} })("hideChannelsFromDefaultChat", false)
    assert(counter.syncs == 1, "chat filters resynced once, got " .. counter.syncs)
  end

  -- test_enabled_channels_change_resyncs_chat_filters
  do
    local counter = syncCounter()
    SettingsHandler.Create({ runtime = counter.runtime, accountSettings = {} })("enabledChannels", { trade = true })
    assert(counter.syncs == 1, "chat filters resynced once, got " .. counter.syncs)
  end

  -- test_filters_change_resyncs_without_saving_a_setting
  do
    local counter = syncCounter()
    local settings = {}
    SettingsHandler.Create({ runtime = counter.runtime, accountSettings = settings })("filters")
    assert(counter.syncs == 1, "chat filters resynced once, got " .. counter.syncs)
    assert(settings.filters == nil, "the ignore list and rules are not a setting")
  end

  -- test_filters_change_refreshes_the_window
  do
    local refreshes = 0
    local runtime = {
      store = { config = {} },
      refreshWindow = function()
        refreshes = refreshes + 1
      end,
    }
    SettingsHandler.Create({ runtime = runtime, accountSettings = {} })("filters")
    assert(refreshes == 1, "window refreshed so the header shows the block state, got " .. refreshes)
  end
end
