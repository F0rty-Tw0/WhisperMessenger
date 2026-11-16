local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

-- A fresh handler per case: { onChange, runtime, remeasures() }.
local function setUp()
  local count = 0
  local runtime = {
    store = { config = {} },
    refreshWindow = function() end,
    window = {
      composer = {
        remeasure = function()
          count = count + 1
        end,
      },
    },
  }
  local fonts = {
    SetMode = function() end,
    SetFontSize = function() end,
    SetOutline = function() end,
  }
  local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = {}, fonts = fonts })

  return {
    onChange = onChange,
    runtime = runtime,
    remeasures = function()
      return count
    end,
  }
end

return function()
  -- test_font_size_change_remeasures_the_composer
  do
    local fixture = setUp()
    fixture.onChange("fontSize", 16)
    assert(fixture.remeasures() == 1, "a font size change remeasures, got " .. fixture.remeasures())
  end

  -- test_font_family_change_remeasures_the_composer
  do
    local fixture = setUp()
    fixture.onChange("fontFamily", "x")
    assert(fixture.remeasures() == 1, "a font family change remeasures, got " .. fixture.remeasures())
  end

  -- test_font_outline_change_remeasures_the_composer
  do
    local fixture = setUp()
    fixture.onChange("fontOutline", "OUTLINE")
    assert(fixture.remeasures() == 1, "an outline change remeasures, got " .. fixture.remeasures())
  end

  -- test_font_color_change_leaves_the_composer_alone
  do
    local fixture = setUp()
    fixture.onChange("fontColor", "x")
    assert(fixture.remeasures() == 0, "a colour change does not remeasure, got " .. fixture.remeasures())
  end

  -- test_no_window_is_fine
  do
    local fixture = setUp()
    fixture.runtime.window = nil
    fixture.onChange("fontSize", 14)
  end

  print("PASS: test_settings_handler_composer_font")
end
