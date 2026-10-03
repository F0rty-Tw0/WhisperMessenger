local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local QuickRepliesSettings = ns.MessengerWindowQuickRepliesSettings or require("WhisperMessenger.UI.MessengerWindow.QuickRepliesSettings")
local ToggleSpecs = ns.MessengerWindowBehaviorToggleSpecs or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.ToggleSpecs")

local BehaviorSettings = {}

local PADDING = Theme.CONTENT_PADDING

local function text(key)
  return Localization.Text(key)
end

local DEFAULTS = ToggleSpecs.DEFAULTS

function BehaviorSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, {
    title = text("Behavior"),
    hint = text("Control how the messenger window behaves."),
  })
  local hint = header.hint

  local toggleSpecs = ToggleSpecs.Build(config, onChange)

  local toggles = SettingsControls.BuildToggleList(factory, frame, hint, toggleSpecs)

  local panel = SettingsControls.NewPanelRegistry()
  SettingsControls.BindToggleSpecs(panel, toggles, toggleSpecs, DEFAULTS)

  -- Not bound to Reset to Defaults: it would wipe replies the player typed.
  local quickReplies = QuickRepliesSettings.Create(factory, frame, toggles[#toggles].row, {
    config = config,
    panel = panel,
    onChange = onChange,
    onLayoutChanged = options.onLayoutChanged,
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
  resetButton:SetPoint("TOPLEFT", quickReplies.bottom, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    panel:reset(onChange)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  -- Marker the options scrollview reads to size the scroll content to this
  -- tab's actual extent. Anchored to the very last control plus a padding
  -- spacer, so its bottom = panel content bottom.
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
    quickReplies.refreshTheme()
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(text("Behavior"))
    header.hint:SetText(text("Control how the messenger window behaves."))
    SettingsControls.RelabelToggles(toggles, toggleSpecs, text)
    resetButton.label:SetText(text("Reset to Defaults"))
    quickReplies.setLanguage()
    -- Tooltip lines were captured into closure-frozen arrays at construction
    -- and stay in the previous language until the toggle is re-hovered after
    -- a /reload. Live-refreshing them would require restructuring the toggle
    -- helper to read keys at hover time; deferred until the codebase needs it.
  end

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    local effective = math.min(maxWidth, math.max(160, math.floor(width)))
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
    quickReplies.refreshLayout(effective)
  end

  return {
    frame = frame,
    quickReplies = quickReplies,
    refreshLayout = refreshLayout,
    refreshTheme = refreshTheme,
    setLanguage = setLanguage,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
