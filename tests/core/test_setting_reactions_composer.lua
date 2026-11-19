local ComposerSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingReactions").ComposerSetting

local function fakeRuntime()
  local calls = {}
  local runtime = {
    window = {
      composer = {
        setEmojiButtonShown = function(shown)
          calls[#calls + 1] = shown
        end,
      },
    },
  }
  return runtime, calls
end

return function()
  -- test_off_hides_the_button
  do
    local runtime, calls = fakeRuntime()
    ComposerSetting.Apply(runtime, "showEmojiButton", false)
    assert(#calls == 1 and calls[1] == false, "off hides the button")
  end

  -- test_on_shows_the_button
  do
    local runtime, calls = fakeRuntime()
    ComposerSetting.Apply(runtime, "showEmojiButton", true)
    assert(#calls == 1 and calls[1] == true, "on shows the button")
  end

  -- test_missing_value_means_shown
  do
    local runtime, calls = fakeRuntime()
    ComposerSetting.Apply(runtime, "showEmojiButton", nil)
    assert(#calls == 1 and calls[1] == true, "a missing value shows the button")
  end

  -- test_other_keys_are_ignored
  do
    local runtime, calls = fakeRuntime()
    ComposerSetting.Apply(runtime, "fontSize", 14)
    assert(#calls == 0, "other settings leave the button alone")
  end

  -- test_no_window_is_fine
  do
    local runtime = fakeRuntime()
    runtime.window = nil
    local ok, err = pcall(ComposerSetting.Apply, runtime, "showEmojiButton", false)
    assert(ok, "no window does not error: " .. tostring(err))
  end

  print("PASS: test_setting_reactions_composer")
end
