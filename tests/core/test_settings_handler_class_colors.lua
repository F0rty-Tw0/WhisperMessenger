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

  -- test_turning_the_option_off_restores_plain_names

  do
    local revision = DisplayName.Revision()
    onChange("classColorSenderNames", false)
    assert(accountSettings.classColorSenderNames == false, "the choice persists")
    assert(DisplayName.ClassColorSenderNames() == false, "sender names go back to the plain colour right away")
    assert(DisplayName.Revision() ~= revision, "cached labels are invalidated")
    assert(refreshes == 1, "the window repaints without a reload")
  end

  -- test_turning_the_option_on_colours_sender_names

  do
    onChange("classColorSenderNames", true)
    assert(DisplayName.ClassColorSenderNames() == true, "sender names switch to class colours")
    assert(refreshes == 2, "the window repaints again")
  end

  DisplayName.Configure({ classColorSenderNames = true })
end
