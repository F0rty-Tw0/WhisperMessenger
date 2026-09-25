local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

return function()
  -- test_quick_replies_saved_account_wide
  local accountSettings = {}
  local onSettingChanged = SettingsHandler.Create({
    runtime = { store = { config = {} } },
    accountSettings = accountSettings,
  })
  local list = { "brb", "gg" }
  onSettingChanged("quickReplies", list)
  assert(accountSettings.quickReplies == list, "quick replies saved in the account-wide settings")
end
