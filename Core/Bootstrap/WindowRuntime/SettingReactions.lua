local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")

-- What a saved setting does right away, without a reload. One table per
-- concern; SettingsHandler calls each of them for every changed key.
local SettingReactions = {}

-- "Esc closes the window": flipping it re-lists the open window and hands the
-- Esc key back or takes it again right away.
local EscapeSetting = {}

-- Applies key when it is the Esc setting; other keys are ignored.
function EscapeSetting.Apply(runtime, key)
  local window = runtime.window
  if key == "escapeClosesWindow" and window and window.refreshEscapeSetting then
    window.refreshEscapeSetting()
  end
end

-- Pushes the settings that change how sender names look into DisplayName.
local DisplayNameSetting = {}

-- Returns true when key is a display name setting and was applied.
function DisplayNameSetting.Apply(displayName, key, value, seenLevelEvents)
  if not (displayName and displayName.Configure) then
    return false
  end
  if key == "hideBattleTagNumbers" then
    displayName.Configure({ hideBattleTagNumbers = value ~= false })
    return true
  end
  if key == "showPlayerLevels" then
    displayName.Configure({ showPlayerLevels = value == true })
    if seenLevelEvents and seenLevelEvents.SetEnabled then
      seenLevelEvents.SetEnabled(value == true)
    end
    return true
  end
  return false
end

-- Settings whose change repaints the open window (contacts, bubbles, labels).
local RefreshingSettings = {}

local REFRESHING_KEYS = {
  hideMessagePreview = true,
  hideBattleTagNumbers = true,
  showPlayerLevels = true,
  whoLookups = true,
  showRelationshipMarks = true,
  showWidgetMessagePreview = true,
  widgetPreviewReply = true,
  fontFamily = true,
  fontSize = true,
  fontOutline = true,
  fontColor = true,
  bubbleColorPreset = true,
  timeFormat = true,
  timeSource = true,
  interfaceLanguage = true,
  enabledChannels = true,
  showInviteLink = true,
  showChannelContext = true,
}

function RefreshingSettings.Has(key)
  return key ~= nil and REFRESHING_KEYS[key] == true
end

-- What a changed Icons-page setting does to the floating widget and the
-- minimap button once the value is saved. Either icon may be absent.
local IconSettingReactions = {}

function IconSettingReactions.Apply(key, value, icon, minimap)
  if key == "iconDesaturated" then
    if icon and icon.refreshDesaturation then
      icon.refreshDesaturation()
    end
    if minimap and minimap.refreshDesaturation then
      minimap.refreshDesaturation()
    end
  end
  -- Widget-only looks: the minimap always wears the gold ring.
  local repaintsIcon = key == "iconBorder" or key == "iconBorderThemed" or key == "iconBackground" or key == "widgetShape"
  if repaintsIcon and icon and icon.refreshTheme then
    icon.refreshTheme()
  end
  if key == "widgetTransparency" and icon and icon.refreshTransparency then
    icon.refreshTransparency()
  end
  if key == "lockToggleIcon" and icon and icon.refreshLockGlyph then
    icon.refreshLockGlyph()
  end

  -- Widget-only: the minimap button and the preview card keep their strata.
  if key == "widgetStrata" and icon and icon.applyStrata then
    icon.applyStrata(value)
  end

  if key == "widgetPreviewPosition" then
    if icon and icon.applyPreviewPosition then
      icon.applyPreviewPosition(value)
    end
    if minimap and minimap.applyPreviewPosition then
      minimap.applyPreviewPosition(value)
    end
  end
end

-- Settings that show or hide a contacts tab. Turning a tab off while it is
-- open falls back to the whispers tab.
local TabVisibilitySetting = {}

local function leaveTab(window, tabMode)
  if window and window.getTabMode and window.getTabMode() == tabMode and window.setTabMode then
    window.setTabMode("whispers")
  end
end

local function refreshToggles(window)
  if window and window.refreshTabToggleVisibility then
    window.refreshTabToggleVisibility()
  end
end

local function refreshWindow(runtime)
  if runtime.refreshWindow then
    runtime.refreshWindow()
  end
end

-- Applies key when it is a tab visibility setting; other keys are ignored.
function TabVisibilitySetting.Apply(runtime, accountSettings, key, value)
  local window = runtime.window
  if key == "showGroupChats" then
    if value == false then
      leaveTab(window, "groups")
    end
    refreshToggles(window)
    refreshWindow(runtime)
  elseif key == "requestsInbox" then
    if value ~= true then
      leaveTab(window, "requests")
    end
    refreshToggles(window)
    refreshWindow(runtime)
  elseif key == "enabledChannels" then
    if not ConversationSnapshot.HasChannelsTab(accountSettings) then
      leaveTab(window, "channels")
    end
    refreshToggles(window)
  end
end

SettingReactions.EscapeSetting = EscapeSetting
SettingReactions.DisplayNameSetting = DisplayNameSetting
SettingReactions.RefreshingSettings = RefreshingSettings
SettingReactions.IconSettingReactions = IconSettingReactions
SettingReactions.TabVisibilitySetting = TabVisibilitySetting

ns.BootstrapWindowRuntimeSettingReactions = SettingReactions
return SettingReactions
