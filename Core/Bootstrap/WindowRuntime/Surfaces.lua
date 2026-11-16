local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconMode = ns.BootstrapWindowRuntimeIconMode or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconMode")
local IconRuntime = ns.BootstrapWindowRuntimeIconRuntime or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local MinimapIconRuntime = ns.BootstrapWindowRuntimeMinimapIconRuntime or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.MinimapIconRuntime")
local DetachedPreviewRuntime = ns.BootstrapWindowRuntimeDetachedPreviewRuntime
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.DetachedPreviewRuntime")

-- Owns every surface outside the window: the widget icon, the minimap button
-- with its data broker object, the detached preview and the addon compartment
-- entry. Each is built on first need and once. The icon mode decides which
-- one a caller gets; the built ones stay, hidden, when the mode leaves them.
local Surfaces = {}

local function showsWidget(mode)
  return mode == "widget" or mode == "both"
end

local function showsMinimap(mode)
  return mode == "minimap" or mode == "both"
end

local function repaint(surface)
  if surface and surface.refreshTheme then
    surface.refreshTheme()
  end
end

local function createIcon(options, handlers, isExternalShownElsewhere)
  return IconRuntime.Create({
    positionSlots = options.positionSlots,
    accountState = options.accountState,
    characterState = options.characterState,
    uiFactory = options.uiFactory,
    toggleIcon = options.toggleIcon,
    tableUtils = options.tableUtils,
    runtime = options.runtime,
    buildContacts = options.buildContacts,
    buildLatestIncomingPreview = options.buildLatestIncomingPreview,
    acknowledgeLatestWidgetPreview = handlers.acknowledgeLatestWidgetPreview,
    refreshWindow = handlers.refreshWindow,
    onToggle = handlers.onToggle,
    onOpenPreview = handlers.onOpenPreview,
    onMarkAllRead = handlers.onMarkAllRead,
    quickReply = handlers.quickReply,
    isExternalShownElsewhere = isExternalShownElsewhere,
  })
end

local function createMinimap(options, handlers)
  return (options.minimapIconRuntime or MinimapIconRuntime).Create({
    positionSlots = options.positionSlots,
    accountState = options.accountState,
    characterState = options.characterState,
    uiFactory = options.uiFactory,
    tableUtils = options.tableUtils,
    runtime = options.runtime,
    buildContacts = options.buildContacts,
    acknowledgeLatestWidgetPreview = handlers.acknowledgeLatestWidgetPreview,
    refreshWindow = handlers.refreshWindow,
    onToggle = handlers.onToggle,
    onOpenPreview = handlers.onOpenPreview,
    onMarkAllRead = handlers.onMarkAllRead,
    quickReply = handlers.quickReply,
  })
end

local function createDetachedPreview(options, handlers, getWidgetIcon)
  return DetachedPreviewRuntime.Create({
    positionSlots = options.positionSlots,
    uiFactory = options.uiFactory,
    uiParent = options.uiParent,
    accountState = options.accountState,
    characterState = options.characterState,
    buildContacts = options.buildContacts,
    acknowledgeLatestWidgetPreview = handlers.acknowledgeLatestWidgetPreview,
    refreshWindow = handlers.refreshWindow,
    onOpenPreview = handlers.onOpenPreview,
    quickReply = handlers.quickReply,
    getWidgetIcon = getWidgetIcon,
  })
end

-- options: runtime, accountState, characterState, uiFactory, uiParent,
-- tableUtils, positionSlots, toggleIcon, minimapIconRuntime, buildContacts,
-- buildLatestIncomingPreview.
function Surfaces.Create(options)
  local runtime = options.runtime
  local accountState = options.accountState

  -- Bound once through setHandlers, before the first surface is built: the
  -- toggle, preview and reply flows are themselves built from the getters below.
  -- Left nil until then, so a surface built too early raises instead of
  -- getting no handlers.
  local handlers
  local icon
  local minimapRuntime
  local minimapIcon
  local detachedPreview
  local compartment

  local function resolveIconMode()
    return IconMode.Resolve(accountState.settings)
  end

  local function isPreviewDetached()
    return DetachedPreviewRuntime.IsDetached(accountState.settings)
  end

  local function getIcon()
    return icon
  end

  local function getMinimap()
    return minimapIcon
  end

  local function getWidgetIcon()
    return showsWidget(resolveIconMode()) and icon or nil
  end

  local function getMinimapIcon()
    return showsMinimap(resolveIconMode()) and minimapIcon or nil
  end

  local function getLdbObject()
    if resolveIconMode() == "none" then
      return nil
    end
    return minimapRuntime and minimapRuntime.getLdbObject() or nil
  end

  local function isExternalShownElsewhere()
    return detachedPreview ~= nil and isPreviewDetached() and detachedPreview.isExternalPreviewShown() == true
  end

  local function ensureIcon()
    if not icon then
      icon = createIcon(options, handlers, isExternalShownElsewhere)
      runtime.icon = icon
    end
    return icon
  end

  local function ensureMinimap()
    if not minimapRuntime then
      minimapRuntime = createMinimap(options, handlers)
      minimapIcon = minimapRuntime.minimapIcon
    end
    return minimapRuntime
  end

  local function ensureDetachedPreview()
    if not detachedPreview then
      detachedPreview = createDetachedPreview(options, handlers, getWidgetIcon)
    end
    return detachedPreview
  end

  local modeSurfaces = { ensureIcon = ensureIcon, ensureMinimap = ensureMinimap, getIcon = getIcon, getMinimap = getMinimap }

  -- Builds what the icon mode needs and shows or hides what exists. Called at
  -- startup and whenever the setting changes.
  local function applyIconMode()
    IconMode.Apply(resolveIconMode(), modeSurfaces)
  end

  -- The entry exists in every icon mode; nil where the game has no compartment.
  local function createCompartment()
    if compartment then
      return compartment
    end
    compartment = MinimapIconRuntime.CreateCompartment({
      accountState = accountState,
      runtime = runtime,
      buildContacts = options.buildContacts,
      onToggle = handlers.onToggle,
      onMarkAllRead = handlers.onMarkAllRead,
    })
    return compartment
  end

  -- Every built surface, shown or hidden: a hidden one comes back in the
  -- theme picked while it was away.
  local function refreshTheme()
    repaint(icon)
    repaint(minimapIcon)
    repaint(detachedPreview)
  end

  return {
    setHandlers = function(nextHandlers)
      handlers = nextHandlers
    end,
    applyIconMode = applyIconMode,
    createCompartment = createCompartment,
    ensureDetachedPreview = ensureDetachedPreview,
    refreshTheme = refreshTheme,
    isPreviewDetached = isPreviewDetached,
    -- The built surface, whatever the icon mode.
    getIcon = getIcon,
    getMinimap = getMinimap,
    getDetachedPreview = function()
      return detachedPreview
    end,
    getCompartment = function()
      return compartment
    end,
    -- The surface only while the icon mode shows it.
    getWidgetIcon = getWidgetIcon,
    getMinimapIcon = getMinimapIcon,
    getLdbObject = getLdbObject,
  }
end

ns.BootstrapWindowRuntimeSurfaces = Surfaces
return Surfaces
