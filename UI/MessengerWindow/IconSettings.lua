local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Options = ns.IconSettingsOptions or require("WhisperMessenger.UI.MessengerWindow.IconSettings.Options")
local UnreadRows = ns.IconSettingsUnreadRows or require("WhisperMessenger.UI.MessengerWindow.IconSettings.UnreadRows")
local LookRows = ns.IconSettingsLookRows or require("WhisperMessenger.UI.MessengerWindow.IconSettings.LookRows")

local IconSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = Options.DEFAULTS

local function text(key)
  return Localization.Text(key)
end

-- The four Widget layer buttons; each explains the setting on hover.
local function strataOptions()
  local options = Options.BuildStrataOptions()
  for _, option in ipairs(options) do
    option.tooltip = text("Sets which game windows the widget sits above. Pick a lower layer to keep bags and other windows on top of it.")
  end
  return options
end

function IconSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, {
    title = text("Icons"),
    hint = text("Configure icon and widget settings."),
  })
  local hint = header.hint

  local toggleColors = SettingsControls.ToggleColors(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }
  local selectorColors = SettingsControls.SelectorColors(Theme)
  local rowSpacing = -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  local panel = SettingsControls.NewPanelRegistry()

  local iconSizeRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = text("Icon Size"),
      min = 24,
      max = 64,
      step = 2,
      initial = config.iconSize or DEFAULTS.iconSize,
      formatFn = Options.PxFormat,
      onChange = function(value)
        onChange("iconSize", value)
      end,
    }),
    { type = "slider", key = "iconSize", default = DEFAULTS.iconSize }
  )
  iconSizeRow.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -24)

  local iconDesaturatedToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Desaturate icon when idle"),
      config.iconDesaturated ~= false,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("iconDesaturated", value)
      end,
      {
        text("Desaturate icon when idle"),
        text("Grays the back chat bubble when there are no unread messages."),
      }
    ),
    { type = "toggle", key = "iconDesaturated", default = DEFAULTS.iconDesaturated }
  )
  iconDesaturatedToggle.row:SetPoint("TOPLEFT", iconSizeRow.row, "BOTTOMLEFT", 0, rowSpacing)

  local lookRows = LookRows.Create(factory, frame, panel, config, onChange, {
    toggleColors = toggleColors,
    toggleLayout = toggleLayout,
    selectorColors = selectorColors,
    rowSpacing = rowSpacing,
    anchor = iconDesaturatedToggle.row,
  })

  local initialWidgetTransparency = tonumber(config.widgetTransparency)
  if initialWidgetTransparency == nil then
    initialWidgetTransparency = DEFAULTS.widgetTransparency
  end
  local widgetTransparencyRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = text("Widget transparency"),
      tooltip = {
        text("Widget transparency"),
        text("Controls how transparent the widget is when not hovered."),
      },
      min = 0,
      max = 1,
      step = 0.05,
      initial = initialWidgetTransparency,
      formatFn = Options.PercentFormat,
      onChange = function(value)
        onChange("widgetTransparency", value)
      end,
    }),
    { type = "slider", key = "widgetTransparency", default = DEFAULTS.widgetTransparency }
  )
  widgetTransparencyRow.row:SetPoint("TOPLEFT", lookRows.lastRow, "BOTTOMLEFT", 0, rowSpacing)

  local lockToggleIconToggle = panel:bind(
    UIHelpers.createToggleRow(factory, frame, text("Lock icon position"), config.lockToggleIcon == true, toggleColors, toggleLayout, function(value)
      onChange("lockToggleIcon", value)
    end, {
      text("Lock icon position"),
      text("Prevents the chat icon from being dragged. A small padlock appears on the icon while locked."),
    }),
    { type = "toggle", key = "lockToggleIcon", default = DEFAULTS.lockToggleIcon }
  )
  lockToggleIconToggle.row:SetPoint("TOPLEFT", widgetTransparencyRow.row, "BOTTOMLEFT", 0, rowSpacing)

  local widgetStrataSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Widget layer"),
      optionsList = strataOptions(),
      fallbackKey = DEFAULTS.widgetStrata,
      initial = config.widgetStrata or DEFAULTS.widgetStrata,
      colors = selectorColors,
      onChange = function(value)
        onChange("widgetStrata", value)
      end,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
      buttonWidth = Options.SELECTOR_BUTTON_WIDTH,
      buttonHeight = Options.SELECTOR_BUTTON_HEIGHT,
      buttonSpacing = Options.SELECTOR_BUTTON_SPACING,
      maxPerRow = 4,
    }),
    { type = "selector", key = "widgetStrata", default = DEFAULTS.widgetStrata }
  )
  widgetStrataSelector.row:SetPoint("TOPLEFT", lockToggleIconToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local shareWidgetPositionToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Same position on every character"),
      config.shareWidgetPosition == true,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("shareWidgetPosition", value)
      end,
      {
        text("Same position on every character"),
        text("Keeps the widget, minimap button, message preview and window in the same place on all characters of this WoW account."),
      }
    ),
    { type = "toggle", key = "shareWidgetPosition", default = DEFAULTS.shareWidgetPosition }
  )
  shareWidgetPositionToggle.row:SetPoint("TOPLEFT", widgetStrataSelector.row, "BOTTOMLEFT", 0, rowSpacing)

  local iconModeSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Icon Mode"),
      optionsList = Options.BuildIconModeOptions(),
      fallbackKey = DEFAULTS.iconMode,
      initial = config.iconMode or DEFAULTS.iconMode,
      colors = selectorColors,
      onChange = function(value)
        onChange("iconMode", value)
      end,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
      buttonWidth = Options.SELECTOR_BUTTON_WIDTH,
      buttonHeight = Options.SELECTOR_BUTTON_HEIGHT,
      buttonSpacing = Options.SELECTOR_BUTTON_SPACING,
      maxPerRow = 4,
    }),
    { type = "selector", key = "iconMode", default = DEFAULTS.iconMode }
  )
  iconModeSelector.row:SetPoint("TOPLEFT", shareWidgetPositionToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local unreadRows = UnreadRows.Create(factory, frame, panel, config, onChange, {
    toggleColors = toggleColors,
    toggleLayout = toggleLayout,
    selectorColors = selectorColors,
    rowSpacing = rowSpacing,
    anchor = iconModeSelector.row,
  })

  local resetButton = panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      text("Reset to Defaults"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, ghost = true }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", unreadRows.positionSelector.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    panel:reset(lookRows.changed)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
    lookRows.refreshAvailability()
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(text("Icons"))
    header.hint:SetText(text("Configure icon and widget settings."))
    iconSizeRow.label:SetText(text("Icon Size"))
    iconDesaturatedToggle.label:SetText(text("Desaturate icon when idle"))
    lookRows.setLanguage()
    widgetTransparencyRow.label:SetText(text("Widget transparency"))
    lockToggleIconToggle.label:SetText(text("Lock icon position"))
    widgetStrataSelector.label:SetText(text("Widget layer"))
    widgetStrataSelector.setOptionsList(strataOptions())
    shareWidgetPositionToggle.label:SetText(text("Same position on every character"))
    iconModeSelector.label:SetText(text("Icon Mode"))
    iconModeSelector.setOptionsList(Options.BuildIconModeOptions())
    unreadRows.setLanguage()
    resetButton.label:SetText(text("Reset to Defaults"))
  end

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    local effective = math.min(maxWidth, math.max(160, math.floor(width)))
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
  end

  return {
    frame = frame,
    refreshTheme = refreshTheme,
    refreshLayout = refreshLayout,
    setLanguage = setLanguage,
  }
end

ns.IconSettings = IconSettings
return IconSettings
