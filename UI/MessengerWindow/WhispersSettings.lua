local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local PageFooter = ns.SettingsControlsPageFooter or require("WhisperMessenger.UI.Shared.SettingsControls.PageFooter")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ToggleSpecs = ns.MessengerWindowWhispersToggleSpecs or require("WhisperMessenger.UI.MessengerWindow.WhispersSettings.ToggleSpecs")
local AddonGreetingsSelector = ns.MessengerWindowWhispersAddonGreetingsSelector
  or require("WhisperMessenger.UI.MessengerWindow.WhispersSettings.AddonGreetingsSelector")
local AddonGreetings = ns.AddonGreetings or require("WhisperMessenger.Model.AddonGreetings")

-- Options page for whisper behavior: hiding whispers from the default chat,
-- auto-open, the Requests inbox, typing status, read receipts, the widget
-- message preview and replying from it, and addon greetings.
local WhispersSettings = {}

local TITLE = "Whispers"
local HINT = "Control how whispers behave."

local function text(key)
  return Localization.Text(key)
end

function WhispersSettings.Create(factory, parent, config, options)
  local saveSetting = options.onChange or function(...)
    local _ = ...
  end
  local requestsInbox = config.requestsInbox == true
  local greetingsSelector
  -- Set once the reply toggle exists; the preview toggle (and its reset) calls it.
  local refreshReplyAvailability
  -- "Send to Requests" follows the Requests toggle live.
  local function onChange(key, value)
    saveSetting(key, value)
    if key == "requestsInbox" then
      requestsInbox = value == true
      if greetingsSelector then
        greetingsSelector.setOptionsList(AddonGreetingsSelector.Options(requestsInbox))
      end
    elseif key == "showWidgetMessagePreview" and refreshReplyAvailability then
      refreshReplyAvailability(value ~= false)
    end
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, { title = text(TITLE), hint = text(HINT) })

  local toggleSpecs = ToggleSpecs.Build(config, onChange)
  local toggles = SettingsControls.BuildToggleList(factory, frame, header.hint, toggleSpecs)

  local panel = SettingsControls.NewPanelRegistry()
  SettingsControls.BindToggleSpecs(panel, toggles, toggleSpecs, ToggleSpecs.DEFAULTS)

  -- The reply toggle is moot while the preview is off; it keeps its value meanwhile.
  local replyAvailability
  for i, spec in ipairs(toggleSpecs) do
    if spec.key == "widgetPreviewReply" then
      replyAvailability = UIHelpers.attachDisabledState(factory, toggles[i].row)
    end
  end
  refreshReplyAvailability = function(previewOn)
    replyAvailability.set(previewOn, not previewOn and text('Turn on "Show widget message preview" to use this.') or nil)
  end
  refreshReplyAvailability(config.showWidgetMessagePreview ~= false)

  greetingsSelector = panel:bind(
    AddonGreetingsSelector.Create(factory, frame, {
      initial = config.addonGreetings,
      requestsInbox = requestsInbox,
      onChange = function(value)
        onChange(AddonGreetings.SETTING_KEY, value)
      end,
    }),
    { type = "selector", key = AddonGreetings.SETTING_KEY, default = AddonGreetings.DEFAULT_MODE }
  )
  greetingsSelector.row:SetPoint("TOPLEFT", toggles[#toggles].row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING)

  local resetButton = PageFooter.CreateResetButton(factory, frame, panel, text("Reset to Defaults"), function()
    panel:reset(onChange)
  end)
  resetButton:SetPoint("TOPLEFT", greetingsSelector.row, "BOTTOMLEFT", 0, -24)
  PageFooter.AddBottomMarker(factory, frame, resetButton)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(text(TITLE))
    header.hint:SetText(text(HINT))
    SettingsControls.RelabelToggles(toggles, toggleSpecs, text)
    greetingsSelector.label:SetText(text(AddonGreetingsSelector.LABEL))
    greetingsSelector.setOptionsList(AddonGreetingsSelector.Options(requestsInbox))
    resetButton.label:SetText(text("Reset to Defaults"))
  end

  local function refreshLayout(width)
    local effective = PageFooter.ClampPanelWidth(width)
    if not effective then
      return
    end
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
  end

  return {
    frame = frame,
    refreshLayout = refreshLayout,
    refreshTheme = refreshTheme,
    setLanguage = setLanguage,
    widgetPreviewReplyAvailability = replyAvailability,
  }
end

ns.WhispersSettings = WhispersSettings
return WhispersSettings
