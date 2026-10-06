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

  -- test_turning_the_option_on_colours_sender_names

  do
    local revision = DisplayName.Revision()
    onChange("classColorSenderNames", true)
    assert(accountSettings.classColorSenderNames == true, "the choice persists")
    assert(DisplayName.ClassColorSenderNames() == true, "sender names switch to class colours right away")
    assert(DisplayName.Revision() ~= revision, "cached labels are invalidated")
    assert(refreshes == 1, "the window repaints without a reload")
  end

  -- test_turning_the_option_off_restores_plain_names

  do
    onChange("classColorSenderNames", false)
    assert(DisplayName.ClassColorSenderNames() == false, "sender names go back to the plain colour")
    assert(refreshes == 2, "the window repaints again")
  end

  DisplayName.Configure({ classColorSenderNames = false })
end
