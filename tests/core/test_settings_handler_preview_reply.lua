local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

return function()
  -- test_changing_widget_preview_reply_refreshes_window

  local refreshes = 0
  local runtime = {
    store = { config = {} },
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  }
  local accountSettings = {}
  local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

  onChange("widgetPreviewReply", true)
  assert(accountSettings.widgetPreviewReply == true, "the choice persists")
  assert(refreshes == 1, "the preview repaints so the reply row shows or hides right away, got: " .. tostring(refreshes))
end
