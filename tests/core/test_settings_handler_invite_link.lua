local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

return function()
  -- test_changing_show_invite_link_refreshes_window

  local refreshes = 0
  local runtime = {
    store = { config = {} },
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  }
  local accountSettings = {}
  local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

  onChange("showInviteLink", false)
  assert(accountSettings.showInviteLink == false, "the choice persists")
  assert(refreshes == 1, "the window repaints so the invite link hides right away, got: " .. tostring(refreshes))
end
