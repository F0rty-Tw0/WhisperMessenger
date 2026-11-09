local EscapeSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.EscapeSetting")

local function fakeRuntime()
  local calls = { refreshes = 0 }
  local runtime = {
    window = {
      refreshEscapeSetting = function()
        calls.refreshes = calls.refreshes + 1
      end,
    },
  }
  return runtime, calls
end

return function()
  -- test_escape_key_calls_window_refresh
  do
    local runtime, calls = fakeRuntime()
    EscapeSetting.Apply(runtime, "escapeClosesWindow")
    assert(calls.refreshes == 1, "the window re-lists itself once, got " .. tostring(calls.refreshes))
  end

  -- test_other_keys_ignored
  do
    local runtime, calls = fakeRuntime()
    EscapeSetting.Apply(runtime, "themePreset")
    assert(calls.refreshes == 0, "other settings leave the Esc state alone, got " .. tostring(calls.refreshes))
  end

  -- test_missing_window_is_safe
  do
    local ok, err = pcall(EscapeSetting.Apply, {}, "escapeClosesWindow")
    assert(ok, "no window yet must not error: " .. tostring(err))
  end

  -- test_missing_refresh_is_safe
  do
    local ok, err = pcall(EscapeSetting.Apply, { window = {} }, "escapeClosesWindow")
    assert(ok, "a window without the refresh must not error: " .. tostring(err))
  end
end
