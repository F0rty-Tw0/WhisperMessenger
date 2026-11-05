local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local function newCase(withMinimap)
  local case = { accountSettings = {}, widgetRepaints = 0, minimapRepaints = 0 }
  local widget = {
    refreshTheme = function()
      case.widgetRepaints = case.widgetRepaints + 1
    end,
  }
  local minimap = {
    refreshTheme = function()
      case.minimapRepaints = case.minimapRepaints + 1
    end,
  }
  local options = {
    runtime = { store = { config = {} } },
    accountSettings = case.accountSettings,
    getIcon = function()
      return widget
    end,
  }
  if withMinimap then
    options.getMinimapIcon = function()
      return minimap
    end
  end
  case.onChange = SettingsHandler.Create(options)

  return case
end

-- The border settings belong to the widget: the minimap ring is always gold.
return function()
  -- test_show_border_change_saves_and_repaints_only_the_widget
  do
    local case = newCase(true)
    case.onChange("iconBorder", false)
    assert(case.accountSettings.iconBorder == false, "saved")
    assert(case.widgetRepaints == 1, "widget repainted, got " .. case.widgetRepaints)
    assert(case.minimapRepaints == 0, "minimap untouched, got " .. case.minimapRepaints)
  end

  -- test_themed_border_change_repaints_only_the_widget
  do
    local case = newCase(true)
    case.onChange("iconBorderThemed", false)
    assert(case.accountSettings.iconBorderThemed == false, "saved")
    assert(case.widgetRepaints == 1, "widget repainted, got " .. case.widgetRepaints)
    assert(case.minimapRepaints == 0, "minimap untouched, got " .. case.minimapRepaints)
  end

  -- test_background_change_repaints_only_the_widget
  do
    local case = newCase(true)
    case.onChange("iconBackground", false)
    assert(case.widgetRepaints == 1, "widget repainted, got " .. case.widgetRepaints)
    assert(case.minimapRepaints == 0, "minimap untouched, got " .. case.minimapRepaints)
  end

  -- test_border_change_without_a_minimap_button_still_repaints_the_widget
  do
    local case = newCase(false)
    case.onChange("iconBorder", false)
    assert(case.widgetRepaints == 1, "widget repainted, got " .. case.widgetRepaints)
  end
end
