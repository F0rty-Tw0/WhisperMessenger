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

  -- test_theme_preset_repaints_the_surfaces
  -- The detached card is one of them: Surfaces owns the list, and
  -- test_window_runtime_theme_refresh checks the card through the real wiring.
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
      refreshSurfacesTheme = function()
        marks = marks + 1
      end,
    })

    onChange("themePreset", "elvui_dark")
    assert(marks == 1, "the surfaces repaint once, got: " .. marks)
    onChange("iconSize", 40)
    assert(marks == 1, "another setting repaints nothing, got: " .. marks)
  end

  -- test_a_rejected_theme_preset_repaints_nothing
  do
    local marks = 0
    local onChange = SettingsHandler.Create({
      runtime = { store = { config = {} } },
      accountSettings = {},
      theme = {
        ResolvePreset = function()
          return "wow_default", false
        end,
      },
      refreshSurfacesTheme = function()
        marks = marks + 1
      end,
    })

    onChange("themePreset", "missing")
    assert(marks == 0, "a preset that did not apply repaints nothing, got: " .. marks)
  end
end
