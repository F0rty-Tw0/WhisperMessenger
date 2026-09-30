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

  -- test_turning_the_option_off_shows_full_battletags

  do
    onChange("hideBattleTagNumbers", false)
    assert(accountSettings.hideBattleTagNumbers == false, "the choice persists")
    assert(DisplayName.Format("Arthas#1234") == "Arthas#1234", "names show the full BattleTag right away")
    assert(refreshes == 1, "the window repaints without a reload")
  end

  -- test_turning_the_option_on_hides_the_numbers_again

  do
    onChange("hideBattleTagNumbers", true)
    assert(DisplayName.Format("Arthas#1234") == "Arthas", "names hide the number again")
    assert(refreshes == 2, "the window repaints again")
  end
end
