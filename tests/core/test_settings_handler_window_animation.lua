local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

return function()
  -- test_window_animation_is_saved_as_a_plain_account_setting
  local runtime = {
    store = { config = {} },
    window = nil,
    refreshWindow = function() end,
  }
  local accountSettings = {}
  local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })
  onChange("windowAnimation", false)
  assert(accountSettings.windowAnimation == false, "the next open reads it, no reload")
  onChange("windowAnimation", true)
  assert(accountSettings.windowAnimation == true)

  -- test_button_glide_is_saved_as_a_plain_account_setting
  onChange("iconGlide", false)
  assert(accountSettings.iconGlide == false, "saved as a plain account setting, no reload")

  -- test_open_at_saved_spot_is_saved_as_a_plain_account_setting
  onChange("openAtSavedSpot", true)
  assert(accountSettings.openAtSavedSpot == true, "saved as a plain account setting, no reload")
end
