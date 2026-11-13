local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")

return function()
  local refreshes = 0
  local runtime = {
    store = { config = {} },
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  }
  local accountSettings = {}
  local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })
  WhoLookup._reset()

  -- test_turning_lookups_off_stops_them_without_reload

  do
    onChange("whoLookups", false)
    assert(accountSettings.whoLookups == false, "the choice persists")
    assert(WhoLookup.IsEnabled() == false, "lookups stop right away")
    assert(refreshes == 1, "the window repaints so the /who zone hides")
  end

  -- test_turning_lookups_on_starts_them_without_reload

  do
    onChange("whoLookups", true)
    assert(WhoLookup.IsEnabled() == true, "lookups start again right away")
    assert(refreshes == 2, "the window repaints again")
  end

  -- test_player_levels_leave_lookups_alone

  do
    onChange("showPlayerLevels", false)
    assert(WhoLookup.IsEnabled() == true, "hiding levels keeps lookups on")
  end

  WhoLookup._reset()
  DisplayName.Configure({ showPlayerLevels = false })
end
