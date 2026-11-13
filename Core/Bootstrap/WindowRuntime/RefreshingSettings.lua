local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Settings whose change repaints the open window (contacts, bubbles, labels).
local RefreshingSettings = {}

local KEYS = {
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
  return key ~= nil and KEYS[key] == true
end

ns.BootstrapWindowRuntimeRefreshingSettings = RefreshingSettings

return RefreshingSettings
