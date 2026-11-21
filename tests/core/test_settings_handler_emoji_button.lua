local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

return function()
  -- test_switching_it_off_saves_and_hides_the_button
  do
    local calls = {}
    local accountSettings = {}
    local runtime = {
      store = { config = {} },
      refreshWindow = function() end,
      window = {
        composer = {
          setEmojiButtonShown = function(shown)
            calls[#calls + 1] = shown
          end,
        },
      },
    }
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings, fonts = {} })
    onChange("showEmojiButton", false)
    assert(accountSettings.showEmojiButton == false, "the choice is saved")
    assert(#calls == 1 and calls[1] == false, "the open composer hides the button")
  end

  print("PASS: test_settings_handler_emoji_button")
end
