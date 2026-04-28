local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local ToggleIcon = ns.ToggleIcon or require("WhisperMessenger.UI.ToggleIcon")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")

local IconRuntime = {}

local function resolveAutoDismissSeconds(settings)
  local value = settings.widgetPreviewAutoDismissSeconds
  if value == nil then
    return 30
  end
  return tonumber(value) or 0
end

local function resolvePreviewPosition(settings)
  local value = settings.widgetPreviewPosition
  if type(value) ~= "string" or value == "" then
    return "right"
  end
  return value
end

local function initializeIconState(icon, contacts, badgeFilter, buildLatestIncomingPreview)
  if icon and icon.setUnreadCount then
    icon.setUnreadCount(badgeFilter.SumWhisperUnread(contacts))
  end

  if icon and icon.setIncomingPreview then
    local preview = buildLatestIncomingPreview(contacts)
    icon.setIncomingPreview(
      preview and preview.senderName or nil,
      preview and preview.messageText or nil,
      preview and preview.classTag or nil
    )
  end
end

function IconRuntime.Create(options)
  options = options or {}

  local accountState = options.accountState or {}
  local settings = accountState.settings or {}
  local characterState = options.characterState or {}
  local uiFactory = options.uiFactory or _G
  local toggleIcon = options.toggleIcon or ToggleIcon
  local tableUtils = options.tableUtils or TableUtils
  local badgeFilter = options.badgeFilter or BadgeFilter
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local buildLatestIncomingPreview = options.buildLatestIncomingPreview or function()
    return nil
  end
  local acknowledgeLatestWidgetPreview = options.acknowledgeLatestWidgetPreview or function() end
  local refreshWindow = options.refreshWindow or function() end
  local onToggle = options.onToggle or function() end

  local function dismissWidgetPreview()
    acknowledgeLatestWidgetPreview(buildContacts())
    return refreshWindow()
  end

  local icon = toggleIcon.Create(uiFactory, {
    state = characterState.icon,
    iconSize = settings.iconSize,
    onToggle = onToggle,
    onPositionChanged = function(nextState)
      characterState.icon = tableUtils.copyState(nextState)
    end,
    getShowUnreadBadge = function()
      return settings.showUnreadBadge ~= false
    end,
    getBadgePulse = function()
      return settings.badgePulse ~= false
    end,
    getIconDesaturated = function()
      return settings.iconDesaturated ~= false
    end,
    getPreviewAutoDismissSeconds = function()
      return resolveAutoDismissSeconds(settings)
    end,
    getPreviewPosition = function()
      return resolvePreviewPosition(settings)
    end,
    onDismissPreview = dismissWidgetPreview,
  })

  initializeIconState(icon, buildContacts(), badgeFilter, buildLatestIncomingPreview)

  return icon
end

ns.BootstrapWindowRuntimeIconRuntime = IconRuntime

return IconRuntime
