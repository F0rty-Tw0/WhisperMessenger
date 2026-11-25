local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local PageFooter = ns.SettingsControlsPageFooter or require("WhisperMessenger.UI.Shared.SettingsControls.PageFooter")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local QuickRepliesSettings = ns.MessengerWindowQuickRepliesSettings or require("WhisperMessenger.UI.MessengerWindow.QuickRepliesSettings")
local ToggleSpecs = ns.MessengerWindowBehaviorToggleSpecs or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.ToggleSpecs")
local IntegrationList = ns.MessengerWindowBehaviorIntegrationList or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.IntegrationList")
local KeybindRow = ns.MessengerWindowBehaviorKeybindRow or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.KeybindRow")

local BehaviorSettings = {}

local function text(key)
  return Localization.Text(key)
end

local DEFAULTS = ToggleSpecs.DEFAULTS

local function rowOfKey(toggleSpecs, toggles, key)
  for index, spec in ipairs(toggleSpecs) do
    if spec.key == key then
      return toggles[index].row
    end
  end
end

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

  -- Double ESC only matters while Esc closes the window; it keeps its value while greyed.
  local escOn = config.escapeClosesWindow ~= false
  local refreshAvailability

  -- Toggle clicks and Reset to Defaults both land here, so Double ESC follows Esc at once.
  local function changed(key, value)
    if key == "escapeClosesWindow" then
      escOn = value
      refreshAvailability()
    end
    onChange(key, value)
  end

  local toggleSpecs = ToggleSpecs.Build(config, changed)

  local toggles = SettingsControls.BuildToggleList(factory, frame, hint, toggleSpecs)

  local panel = SettingsControls.NewPanelRegistry()
  SettingsControls.BindToggleSpecs(panel, toggles, toggleSpecs, DEFAULTS)

  local doubleEsc = UIHelpers.attachDisabledState(factory, rowOfKey(toggleSpecs, toggles, "doubleEscapeToClose"))
  refreshAvailability = function()
    doubleEsc.set(escOn, nil)
  end
  refreshAvailability()

  -- Not bound to Reset to Defaults: the ticks are per addon, not a page default.
  local list = options.integrations
    and IntegrationList.Create(factory, frame, toggles[#toggles].row, {
      integrations = options.integrations,
      onLayoutChanged = options.onLayoutChanged,
    })

  local keybind = KeybindRow.Create(factory, frame, list and list.bottom or toggles[#toggles].row, { panel = panel })

  -- Not bound to Reset to Defaults: it would wipe replies the player typed.
  local quickReplies = QuickRepliesSettings.Create(factory, frame, keybind.bottom, {
    config = config,
    panel = panel,
    onChange = onChange,
    onLayoutChanged = options.onLayoutChanged,
  })

  local resetButton = PageFooter.CreateResetButton(factory, frame, panel, text("Reset to Defaults"), function()
    panel:reset(changed)
  end)
  resetButton:SetPoint("TOPLEFT", quickReplies.bottom, "BOTTOMLEFT", 0, -24)
  PageFooter.AddBottomMarker(factory, frame, resetButton)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
    if list then
      list.refreshTheme()
    end
    keybind.refreshTheme()
    quickReplies.refreshTheme()
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(text("Behavior"))
    header.hint:SetText(text("Control how the messenger window behaves."))
    SettingsControls.RelabelToggles(toggles, toggleSpecs, text)
    resetButton.label:SetText(text("Reset to Defaults"))
    if list then
      list.setLanguage()
    end
    keybind.setLanguage()
    quickReplies.setLanguage()
    -- Tooltip lines were captured into closure-frozen arrays at construction
    -- and stay in the previous language until the toggle is re-hovered after
    -- a /reload. Live-refreshing them would require restructuring the toggle
    -- helper to read keys at hover time; deferred until the codebase needs it.
  end

  local function refreshLayout(width)
    local effective = PageFooter.ClampPanelWidth(width)
    if not effective then
      return
    end
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
    if list then
      list.refreshLayout(effective)
    end
    quickReplies.refreshLayout(effective)
  end

  return {
    frame = frame,
    quickReplies = quickReplies,
    refreshLayout = refreshLayout,
    refreshTheme = refreshTheme,
    setLanguage = setLanguage,
    -- Shows a value without saving it (a cancelled reload).
    setAllowAddonIntegration = function(on)
      for i, spec in ipairs(toggleSpecs) do
        if spec.key == "allowAddonIntegration" then
          toggles[i].setValue(on)
        end
      end
    end,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
