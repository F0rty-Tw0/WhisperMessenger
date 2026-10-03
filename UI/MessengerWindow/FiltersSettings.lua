local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local HelpSection = ns.FiltersSettingsHelpSection or require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.HelpSection")
local IgnoreListSection = ns.FiltersSettingsIgnoreListSection or require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.IgnoreListSection")
local RulesSection = ns.FiltersSettingsRulesSection or require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.RulesSection")

-- Options page for the account-wide spam controls: the silent ignore list and
-- keyword rules. Both edit `config.filters` (the saved filters table) in place.
local FiltersSettings = {}

local PADDING = Theme.CONTENT_PADDING
local TITLE = "Filters"
local HINT = "Silently hide messages from players and lines you don't want to see."

local function text(key)
  return Localization.Text(key)
end

function FiltersSettings.Create(factory, parent, config, options)
  options = options or {}
  local filters = config.filters

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, { title = text(TITLE), hint = text(HINT) })
  local panel = SettingsControls.NewPanelRegistry()
  local sectionOptions = { filters = filters, panel = panel, onLayoutChanged = options.onLayoutChanged }

  local helpSection = HelpSection.Create(frame, header.hint)
  local ignoreSection = IgnoreListSection.Create(factory, frame, helpSection.bottom, sectionOptions)
  local rulesSection = RulesSection.Create(factory, frame, ignoreSection.bottom, sectionOptions)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", rulesSection.bottom, "BOTTOMLEFT", 0, 0)
  -- Marker the options scrollview reads to size the scroll content.
  frame._wmBottomMarker = bottomSpacer

  -- Blocked counts move while the page is closed.
  frame:SetScript("OnShow", function()
    ignoreSection.redraw()
    rulesSection.redraw()
  end)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
    helpSection.refreshTheme()
    ignoreSection.refreshTheme()
    rulesSection.refreshTheme()
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(text(TITLE))
    header.hint:SetText(text(HINT))
    helpSection.setLanguage()
    ignoreSection.setLanguage()
    rulesSection.setLanguage()
  end

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local effective = math.min(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, math.max(160, math.floor(width)))
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
    helpSection.refreshLayout(effective)
    ignoreSection.refreshLayout(effective)
    rulesSection.refreshLayout(effective)
  end

  return {
    frame = frame,
    refreshLayout = refreshLayout,
    refreshTheme = refreshTheme,
    setLanguage = setLanguage,
  }
end

ns.FiltersSettings = FiltersSettings
return FiltersSettings
