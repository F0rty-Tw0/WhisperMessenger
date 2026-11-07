local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconSettingsOptions = ns.IconSettingsOptions or require("WhisperMessenger.UI.MessengerWindow.IconSettings.Options")

local DockedLook = {}

-- Getter name on the ToggleIcon options -> key in the Icons panel defaults.
local LOOK_GETTERS = {
  { getter = "getWidgetShape", key = "widgetShape" },
  { getter = "getIconBorder", key = "iconBorder" },
  { getter = "getIconBackground", key = "iconBackground" },
  { getter = "getIconBorderThemed", key = "iconBorderThemed" },
}

local function wrapGetter(options, isDocked, name, defaultKey)
  return function()
    if isDocked() then
      return IconSettingsOptions.DEFAULTS[defaultKey]
    end

    local getter = options[name]
    if getter == nil then
      return nil
    end

    return getter()
  end
end

-- While docked the four look getters answer with the default circle; floating they pass the saved values through.
function DockedLook.Wrap(options, isDocked)
  local wrapped = {}
  for _, look in ipairs(LOOK_GETTERS) do
    wrapped[look.getter] = wrapGetter(options, isDocked, look.getter, look.key)
  end

  return wrapped
end

ns.ToggleIconDockedLook = DockedLook
return DockedLook
