local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

return function()
  -- test_any_setting_reaches_the_detached_hook_after_icon_mode
  do
    local log = {}
    local onChange = SettingsHandler.Create({
      runtime = { store = { config = {} } },
      accountSettings = {},
      applyIconMode = function()
        log[#log + 1] = "applyIconMode"
      end,
      onDetachedSetting = function(key, value)
        log[#log + 1] = "detached:" .. tostring(key) .. "=" .. tostring(value)
      end,
    })

    onChange("iconMode", "both")
    assert(#log == 2, "both hooks run once, got: " .. #log)
    assert(log[1] == "applyIconMode", "icon mode applies first, got: " .. tostring(log[1]))
    assert(log[2] == "detached:iconMode=both", "detached hook sees the persisted value, got: " .. tostring(log[2]))
  end

  -- test_theme_preset_repaints_the_detached_card
  do
    local marks = 0
    local theme = {
      DEFAULT_PRESET = "wow_default",
      ResolvePreset = function(key)
        return key, true
      end,
    }
    local onChange = SettingsHandler.Create({
      runtime = { store = { config = {} } },
      accountSettings = {},
      theme = theme,
      getDetachedPreview = function()
        return {
          refreshTheme = function()
            marks = marks + 1
          end,
        }
      end,
    })

    onChange("themePreset", "elvui_dark")
    assert(marks == 1, "the detached card repaints once, got: " .. marks)
  end
end
