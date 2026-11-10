local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconSurfaces = ns.BootstrapWindowCoordinatorIconSurfaces or require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")
local MinimapIcon = ns.MinimapIcon or require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local DataBroker = ns.MinimapIconDataBroker or require("WhisperMessenger.UI.MinimapIcon.DataBroker")
local AddonCompartment = ns.MinimapIconAddonCompartment or require("WhisperMessenger.UI.MinimapIcon.AddonCompartment")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local IconRuntime = ns.BootstrapWindowRuntimeIconRuntime or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local PositionSlots = ns.BootstrapWindowRuntimePositionSlots or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PositionSlots")

local MinimapIconRuntime = {}

-- Wires the minimap icon and the LibDataBroker launcher into the runtime:
-- settings getters, position persistence, preview dismissal, and the initial
-- count seed (one contacts walk shared by both surfaces; panel badges
-- included, so a surface created after a registration shows them at once).
function MinimapIconRuntime.Create(options)
  options = options or {}

  local accountState = options.accountState or {}
  local characterState = options.characterState or {}
  local uiFactory = options.uiFactory or _G
  local minimapIconModule = options.minimapIcon or MinimapIcon
  local dataBroker = options.dataBroker or DataBroker
  local tableUtils = options.tableUtils or TableUtils
  local runtime = options.runtime or {}
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local acknowledgeLatestWidgetPreview = options.acknowledgeLatestWidgetPreview or function() end
  local refreshWindow = options.refreshWindow or function() end
  local onToggle = options.onToggle or function() end
  local positionSlots = options.positionSlots
    or PositionSlots.Create({ accountState = accountState, characterState = characterState, tableUtils = tableUtils })

  -- Re-read on every call so a profile reset that swaps the settings table
  -- is picked up immediately.
  local function settings()
    return accountState.settings or {}
  end

  local total, unread = IconSurfaces.Counts(buildContacts(), runtime.panelRegistry)

  local minimapIcon = minimapIconModule.Create(uiFactory, {
    state = positionSlots.read("minimapIcon"),
    onToggle = onToggle,
    onMarkAllRead = options.onMarkAllRead,
    onPositionChanged = function(nextState)
      positionSlots.write("minimapIcon", nextState)
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
    getHideFromDefaultChat = function()
      return settings().hideFromDefaultChat == true
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
    onOpenPreview = options.onOpenPreview,
    quickReply = options.quickReply,
  })
  IconSurfaces.ShowCounts(total, unread, minimapIcon)

  local ldbObject
  dataBroker.Register({
    onToggle = onToggle,
    onRegistered = function(obj)
      ldbObject = obj
      IconSurfaces.ShowCounts(total, unread, nil, nil, obj)
    end,
  })

  return {
    minimapIcon = minimapIcon,
    getLdbObject = function()
      return ldbObject
    end,
  }
end

-- The Retail addon compartment entry: the minimap icon's click and tooltip,
-- seeded with the current count. It exists in every icon mode, so a player
-- who hides both icons can still open the messenger from it. Nil where the
-- game has no compartment (Classic flavors, WoW: Forever).
function MinimapIconRuntime.CreateCompartment(options)
  options = options or {}
  local accountState = options.accountState or {}
  local runtime = options.runtime or {}
  local entry = (options.addonCompartment or AddonCompartment).Register({
    onToggle = options.onToggle or function() end,
    onMarkAllRead = options.onMarkAllRead,
    getHideFromDefaultChat = function()
      return accountState.settings ~= nil and accountState.settings.hideFromDefaultChat == true
    end,
  })
  if entry then
    entry.setUnreadCount(IconSurfaces.Counts(options.buildContacts(), runtime.panelRegistry))
  end
  return entry
end

ns.BootstrapWindowRuntimeMinimapIconRuntime = MinimapIconRuntime

return MinimapIconRuntime
