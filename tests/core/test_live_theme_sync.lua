local LiveThemeSync = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.LiveThemeSync")

local function fakeBridge()
  local bridge = { listeners = {}, installs = 0 }
  function bridge.OnChange(fn)
    bridge.listeners[#bridge.listeners + 1] = fn
  end
  function bridge.Install()
    bridge.installs = bridge.installs + 1
    return true
  end
  function bridge.fire()
    for _, fn in ipairs(bridge.listeners) do
      fn()
    end
  end
  return bridge
end

local function fakeTheme(activeKey)
  local theme = { applied = {} }
  function theme.GetPreset()
    return activeKey
  end
  function theme.IsLivePreset(key)
    return key == "ellesmere_ui"
  end
  function theme.SetPreset(key)
    theme.applied[#theme.applied + 1] = key
    return true
  end
  return theme
end

return function()
  -- test_install_registers_the_bridge
  do
    local bridge = fakeBridge()
    assert(LiveThemeSync.Install(bridge, fakeTheme("wow_default"), function() end) == true, "installs")
    assert(bridge.installs == 1, "bridge installed once")
  end

  -- test_change_reapplies_the_live_preset_and_repaints_the_icons_before_the_window_exists
  do
    local bridge = fakeBridge()
    local theme = fakeTheme("ellesmere_ui")
    local repaintedAfter
    LiveThemeSync.Install(bridge, theme, function()
      return nil
    end, function()
      repaintedAfter = #theme.applied
    end)
    bridge.fire()
    assert(theme.applied[1] == "ellesmere_ui", "preset colors re-read")
    assert(repaintedAfter == 1, "widget and minimap button repainted after the colors, got " .. tostring(repaintedAfter))
  end

  -- test_change_goes_through_the_settings_handler_once_the_window_exists
  do
    local bridge = fakeBridge()
    local theme = fakeTheme("ellesmere_ui")
    local changes = {}
    local repainted = false
    LiveThemeSync.Install(bridge, theme, function()
      return function(key, value)
        changes[#changes + 1] = key .. "=" .. value
      end
    end, function()
      repainted = true
    end)
    bridge.fire()
    assert(changes[1] == "themePreset=ellesmere_ui", "window repainted through the settings handler")
    assert(#theme.applied == 0, "settings handler does the applying")
    assert(repainted == false, "the settings handler repaints the icons itself")
  end

  -- test_change_ignored_for_fixed_presets
  do
    local bridge = fakeBridge()
    local theme = fakeTheme("elvui_dark")
    local called = false
    LiveThemeSync.Install(bridge, theme, function()
      return function()
        called = true
      end
    end)
    bridge.fire()
    assert(called == false and #theme.applied == 0, "a fixed preset is left alone")
  end
end
