local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local DisplayName = require("WhisperMessenger.Util.DisplayName")

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

  -- test_turning_the_option_on_shows_levels

  do
    local revision = DisplayName.Revision()
    onChange("showPlayerLevels", true)
    assert(accountSettings.showPlayerLevels == true, "the choice persists")
    assert(DisplayName.ShowPlayerLevels() == true, "levels show right away")
    assert(DisplayName.Revision() ~= revision, "cached labels are invalidated")
    assert(refreshes == 1, "the window repaints without a reload")
  end

  -- test_turning_the_option_off_hides_levels

  do
    onChange("showPlayerLevels", false)
    assert(DisplayName.ShowPlayerLevels() == false, "levels hide again")
    assert(refreshes == 2, "the window repaints again")
  end

  DisplayName.Configure({ showPlayerLevels = false })
end
