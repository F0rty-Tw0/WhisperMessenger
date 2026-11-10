local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconSurfaces = ns.BootstrapWindowCoordinatorIconSurfaces or require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")
local ToggleIcon = ns.ToggleIcon or require("WhisperMessenger.UI.ToggleIcon")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local PositionSlots = ns.BootstrapWindowRuntimePositionSlots or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PositionSlots")

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

-- Shared with MinimapIconRuntime so preview defaults live in one place.
IconRuntime.ResolveAutoDismissSeconds = resolveAutoDismissSeconds
IconRuntime.ResolvePreviewPosition = resolvePreviewPosition

-- panelRegistry: a surface created after panels registered shows their
-- badges at once, not on the next icon refresh.
local function initializeIconState(icon, contacts, panelRegistry, buildLatestIncomingPreview)
  local total, unread = IconSurfaces.Counts(contacts, panelRegistry)
  IconSurfaces.ShowCounts(total, unread, icon)

  if icon and icon.setIncomingPreview then
    local preview = buildLatestIncomingPreview(contacts)
    icon.setIncomingPreview(
      preview and preview.senderName or nil,
      preview and preview.messageText or nil,
      preview and preview.classTag or nil,
      preview
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
  local runtime = options.runtime or {}
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local buildLatestIncomingPreview = options.buildLatestIncomingPreview or function()
    return nil
  end
  local acknowledgeLatestWidgetPreview = options.acknowledgeLatestWidgetPreview or function() end
  local refreshWindow = options.refreshWindow or function() end
  local onToggle = options.onToggle or function() end

  local positionSlots = options.positionSlots
    or PositionSlots.Create({ accountState = accountState, characterState = characterState, tableUtils = tableUtils })

  local function dismissWidgetPreview()
    acknowledgeLatestWidgetPreview(buildContacts())
    return refreshWindow()
  end

  local icon = toggleIcon.Create(uiFactory, {
    state = positionSlots.read("icon"),
    iconSize = settings.iconSize,
    onToggle = onToggle,
    onMarkAllRead = options.onMarkAllRead,
    onPositionChanged = function(nextState)
      positionSlots.write("icon", nextState)
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
    getIconBackground = function()
      return settings.iconBackground ~= false
    end,
    getIconBorder = function()
      return settings.iconBorder ~= false
    end,
    getIconBorderThemed = function()
      return settings.iconBorderThemed ~= false
    end,
    getWidgetShape = function()
      return settings.widgetShape == "square" and "square" or "circle"
    end,
    getWidgetStrata = function()
      return (accountState.settings or {}).widgetStrata
    end,
    getWidgetTransparency = function()
      return settings.widgetTransparency or 0
    end,
    getIsLocked = function()
      return settings.lockToggleIcon == true
    end,
    getHideFromDefaultChat = function()
      return settings.hideFromDefaultChat == true
    end,
    getPreviewAutoDismissSeconds = function()
      return resolveAutoDismissSeconds(settings)
    end,
    getPreviewPosition = function()
      return resolvePreviewPosition(settings)
    end,
    onDismissPreview = dismissWidgetPreview,
    onOpenPreview = options.onOpenPreview,
    quickReply = options.quickReply,
    isExternalShownElsewhere = options.isExternalShownElsewhere,
  })

  initializeIconState(icon, buildContacts(), runtime.panelRegistry, buildLatestIncomingPreview)

  return icon
end

ns.BootstrapWindowRuntimeIconRuntime = IconRuntime

return IconRuntime
