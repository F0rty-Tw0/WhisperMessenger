local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

-- Helper: build a minimal runtime + accountSettings pair with spies.
local function makeRuntime()
  local calls = {
    setTabMode = {},
    refreshTabToggleVisibility = 0,
    refreshWindow = 0,
  }
  local runtime = {
    store = { config = {} },
    window = {
      setTabMode = function(mode)
        table.insert(calls.setTabMode, mode)
      end,
      refreshTabToggleVisibility = function()
        calls.refreshTabToggleVisibility = calls.refreshTabToggleVisibility + 1
      end,
    },
    refreshWindow = function()
      calls.refreshWindow = calls.refreshWindow + 1
    end,
  }
  return runtime, calls
end

return function()
  -- test_show_group_chats_disabled_forces_whispers_mode
  do
    local runtime, calls = makeRuntime()
    local accountSettings = { showGroupChats = true }
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("showGroupChats", false)

    assert(accountSettings.showGroupChats == false, "accountSettings.showGroupChats should be persisted as false")
    assert(#calls.setTabMode == 1, "setTabMode should be invoked once when disabling, got: " .. #calls.setTabMode)
    assert(calls.setTabMode[1] == "whispers", 'setTabMode should be called with "whispers" when disabling, got: ' .. tostring(calls.setTabMode[1]))
    assert(
      calls.refreshTabToggleVisibility == 1,
      "refreshTabToggleVisibility should be called exactly once, got: " .. calls.refreshTabToggleVisibility
    )
    assert(calls.refreshWindow == 1, "refreshWindow should be called exactly once, got: " .. calls.refreshWindow)
  end

  -- test_show_group_chats_enabled_does_not_force_mode
  do
    local runtime, calls = makeRuntime()
    local accountSettings = { showGroupChats = false }
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("showGroupChats", true)

    assert(accountSettings.showGroupChats == true, "accountSettings.showGroupChats should be persisted as true")
    assert(#calls.setTabMode == 0, "setTabMode should NOT be called when enabling (user's last mode is preserved), got: " .. #calls.setTabMode)
    assert(
      calls.refreshTabToggleVisibility == 1,
      "refreshTabToggleVisibility should be called exactly once, got: " .. calls.refreshTabToggleVisibility
    )
    assert(calls.refreshWindow == 1, "refreshWindow should be called exactly once, got: " .. calls.refreshWindow)
  end

  -- test_show_group_chats_disabled_is_safe_when_window_missing
  -- Runtime may not have a window wired up in some bootstrap paths (e.g. the
  -- icon created before the messenger window). The handler must not crash.
  do
    local calls = { refreshWindow = 0 }
    local runtime = {
      store = { config = {} },
      window = nil,
      refreshWindow = function()
        calls.refreshWindow = calls.refreshWindow + 1
      end,
    }
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    local ok = pcall(onChange, "showGroupChats", false)
    assert(ok, "onChange must not crash when runtime.window is nil")
    assert(accountSettings.showGroupChats == false, "setting should still persist when window is absent")
    assert(calls.refreshWindow == 1, "refreshWindow should still fire when window is absent")
  end

  -- test_unrelated_setting_does_not_touch_tab_toggle
  do
    local runtime, calls = makeRuntime()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("dimWhenMoving", true)

    assert(#calls.setTabMode == 0, "setTabMode should not fire for unrelated setting")
    assert(calls.refreshTabToggleVisibility == 0, "refreshTabToggleVisibility should not fire for unrelated setting")
  end
end
