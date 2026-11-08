local Localization = require("WhisperMessenger.Locale.Localization")
local Options = require("WhisperMessenger.UI.MessengerWindow.IconSettings.Options")

return function()
  Localization.Configure({ language = "enUS" })

  -- test_slider_formats_round_values

  assert(Options.PxFormat(41.6) == "42px", "test_slider_formats_round_values: px got " .. Options.PxFormat(41.6))
  assert(Options.PercentFormat(0.35) == "35%", "test_slider_formats_round_values: percent got " .. Options.PercentFormat(0.35))
  assert(Options.SecondsFormat(30) == "30s", "test_slider_formats_round_values: seconds got " .. Options.SecondsFormat(30))

  -- test_zero_seconds_reads_off

  assert(Options.SecondsFormat(0) == "Off", "test_zero_seconds_reads_off: got " .. Options.SecondsFormat(0))

  -- test_position_options_keep_order

  local keys = {}
  for _, option in ipairs(Options.BuildPositionOptions()) do
    keys[#keys + 1] = option.key
  end
  assert(table.concat(keys, ",") == "right,left,top,bottom,detached", "test_position_options_keep_order: got " .. table.concat(keys, ","))

  -- test_icon_mode_options_and_default

  local modes = Options.BuildIconModeOptions()
  assert(#modes == 4 and modes[4].key == "none", "test_icon_mode_options_and_default: four modes ending in none")
  assert(Options.DEFAULTS.iconMode == "widget", "test_icon_mode_options_and_default: widget is the default mode")

  -- test_border_defaults_are_on

  assert(Options.DEFAULTS.iconBorder == true, "test_border_defaults_are_on: border is on")
  assert(Options.DEFAULTS.iconBorderThemed == true, "test_border_defaults_are_on: themed border is on")
end
