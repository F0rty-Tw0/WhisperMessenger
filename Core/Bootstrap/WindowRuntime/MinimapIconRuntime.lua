local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local MinimapIcon = ns.MinimapIcon or require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local DataBroker = ns.MinimapIconDataBroker or require("WhisperMessenger.UI.MinimapIcon.DataBroker")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local IconRuntime = ns.BootstrapWindowRuntimeIconRuntime or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")

local MinimapIconRuntime = {}

-- Wires the minimap icon and the LibDataBroker launcher into the runtime:
-- settings getters, position persistence, preview dismissal, and the initial
-- unread seed (one contacts walk shared by both surfaces).
function MinimapIconRuntime.Create(options)
  options = options or {}

  local accountState = options.accountState or {}
  local characterState = options.characterState or {}
  local uiFactory = options.uiFactory or _G
  local minimapIconModule = options.minimapIcon or MinimapIcon
  local dataBroker = options.dataBroker or DataBroker
  local tableUtils = options.tableUtils or TableUtils
  local badgeFilter = options.badgeFilter or BadgeFilter
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local acknowledgeLatestWidgetPreview = options.acknowledgeLatestWidgetPreview or function() end
  local refreshWindow = options.refreshWindow or function() end
  local onToggle = options.onToggle or function() end

  -- Re-read on every call so a profile reset that swaps the settings table
  -- is picked up immediately.
  local function settings()
    return accountState.settings or {}
  end

  local initialUnread = badgeFilter.SumWhisperUnread(buildContacts())

  local minimapIcon = minimapIconModule.Create(uiFactory, {
    state = characterState.minimapIcon,
    onToggle = onToggle,
    onPositionChanged = function(nextState)
      characterState.minimapIcon = tableUtils.copyState(nextState)
    end,
    getShowUnreadBadge = function()
      return settings().showUnreadBadge ~= false
    end,
    getBadgePulse = function()
      return settings().badgePulse ~= false
    end,
    getIconDesaturated = function()
      return settings().iconDesaturated ~= false
    end,
    getPreviewPosition = function()
      return IconRuntime.ResolvePreviewPosition(settings())
    end,
    getPreviewAutoDismissSeconds = function()
      return IconRuntime.ResolveAutoDismissSeconds(settings())
    end,
    onDismissPreview = function()
      acknowledgeLatestWidgetPreview(buildContacts())
      refreshWindow()
    end,
    unreadCount = initialUnread,
  })

  local ldbObject
  dataBroker.Register({
    onToggle = onToggle,
    onRegistered = function(obj)
      ldbObject = obj
      obj.unread = initialUnread
      obj.text = dataBroker.FormatText(initialUnread)
    end,
  })

  return {
    minimapIcon = minimapIcon,
    getLdbObject = function()
      return ldbObject
    end,
  }
end

ns.BootstrapWindowRuntimeMinimapIconRuntime = MinimapIconRuntime

return MinimapIconRuntime
