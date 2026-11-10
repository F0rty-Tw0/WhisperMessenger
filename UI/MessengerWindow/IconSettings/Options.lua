local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The Icons panel's defaults, selector option lists and slider value formats.
local Options = {}

Options.DEFAULTS = {
  badgePulse = true,
  showUnreadBadge = true,
  iconSize = 42,
  iconDesaturated = true,
  iconBackground = true,
  iconBorder = true,
  iconBorderThemed = true,
  widgetShape = "circle",
  widgetStrata = "HIGH",
  lockToggleIcon = false,
  shareWidgetPosition = false,
  widgetTransparency = 0,
  widgetPreviewAutoDismissSeconds = 30,
  widgetPreviewPosition = "right",
  iconMode = "widget",
}

-- Button size and gap of the panel's selector rows.
Options.SELECTOR_BUTTON_WIDTH = 60
Options.SELECTOR_BUTTON_HEIGHT = 26
Options.SELECTOR_BUTTON_SPACING = 4

local POSITION_OPTION_SPECS = {
  { key = "right", label = "Right" },
  { key = "left", label = "Left" },
  { key = "top", label = "Above" },
  { key = "bottom", label = "Below" },
  { key = "detached", label = "Detached" },
}

local function text(key)
  return Localization.Text(key)
end

function Options.BuildPositionOptions()
  local options = {}
  for _, spec in ipairs(POSITION_OPTION_SPECS) do
    options[#options + 1] = { key = spec.key, label = text(spec.label) }
  end
  return options
end

function Options.BuildIconModeOptions()
  return {
    { key = "widget", label = text("Widget") },
    { key = "minimap", label = text("Minimap") },
    { key = "both", label = text("Both") },
    { key = "none", label = text("None") },
  }
end

function Options.BuildWidgetShapeOptions()
  local options = {
    { key = "circle", label = text("Circle") },
    { key = "square", label = text("Square") },
  }

  return options
end

function Options.BuildStrataOptions()
  return {
    { key = "BACKGROUND", label = text("Background") },
    { key = "LOW", label = text("Low") },
    { key = "MEDIUM", label = text("Medium") },
    { key = "HIGH", label = text("High") },
  }
end

function Options.PxFormat(v)
  return tostring(math.floor(v + 0.5)) .. "px"
end

function Options.PercentFormat(v)
  return tostring(math.floor(v * 100 + 0.5)) .. "%"
end

function Options.SecondsFormat(v)
  local n = math.floor(v + 0.5)
  if n <= 0 then
    return text("Off")
  end
  return tostring(n) .. "s"
end

ns.IconSettingsOptions = Options
return Options
