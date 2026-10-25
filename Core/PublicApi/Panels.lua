local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")

-- RegisterPanel / ShowPanel / TogglePanel / IsPanelShown / RefreshPanelBadge:
-- another addon's panel in the messenger window, opened from its own tab in
-- the strip below the window, after the built-in tabs, labelled with `title`
-- as given. `icon` is accepted and ignored. The first registration of a key wins.
-- A panel is { title, onShow(host), onHide?(), onSplit?(host, listWidth), badge?(),
-- onMarkAllRead?(), onUnreadChanged?() }.
-- onSplit runs after onShow and again whenever the contacts divider moves:
-- listWidth is the divider's x from the panel's left edge (about 50 with the
-- contacts collapsed to the rail), so a panel can line up with the list.
-- badge() is the count on the panel's tab, and WM's icons (widget, minimap,
-- LDB) add it to the unread whispers; fractions round down, below 1 or not a
-- finite number shows nothing, and it caps at 999. It never
-- starts the icon glow. It may run on every icon refresh, so keep it cheap.
-- badge() must not call any WhisperMessenger API: it runs inside WM's own
-- refreshes, so a call back in re-enters them.
-- onMarkAllRead() runs when the player marks everything read (Shift-click on the
-- widget, minimap or Broker icon, or Mark all as read in the window). Mark your
-- own items seen so badge() drops; WM refreshes the icons right after. It may
-- call the WhisperMessenger API.
-- onUnreadChanged() runs on the next frame after any WoW whisper's unread count
-- changes (one call per frame at most); it may call the WhisperMessenger API;
-- re-read counts with GetUnreadCount.
local Panels = {}

-- The panel is already stored when this runs: an icon error must not turn
-- the answer into false, since a retry of the same key is refused.
local function refreshIcons(runtime)
  if runtime.updateIconSurfaces then
    pcall(runtime.updateIconSurfaces)
  end
end

local function isOptionalFunction(value)
  return value == nil or type(value) == "function"
end

local function isValidPanel(panel)
  return type(panel) == "table"
    and Guards.IsNonEmptyString(panel.title)
    and type(panel.onShow) == "function"
    and isOptionalFunction(panel.onHide)
    and isOptionalFunction(panel.onSplit)
    and isOptionalFunction(panel.badge)
    and isOptionalFunction(panel.onMarkAllRead)
    and isOptionalFunction(panel.onUnreadChanged)
end

-- The registry keeps this copy, read once: a caller that changes its table
-- later cannot break the tab or window build.
local function copyPanel(panel)
  if type(panel) ~= "table" then
    return nil
  end
  return {
    title = panel.title,
    onShow = panel.onShow,
    onHide = panel.onHide,
    onSplit = panel.onSplit,
    badge = panel.badge,
    onMarkAllRead = panel.onMarkAllRead,
    onUnreadChanged = panel.onUnreadChanged,
  }
end

local function isKnown(runtime, key)
  return Guards.IsNonEmptyString(key) and runtime.panelRegistry.get(key) ~= nil
end

-- Open the window on a registered panel. False, with nothing opened, when the
-- key is unknown or content restrictions refuse; also the icons' click path.
function Panels.Open(runtime, key)
  if not isKnown(runtime, key) or Guards.IsRefused(runtime) then
    return false
  end
  runtime.ensureWindow()
  runtime.setWindowVisible(true)
  return runtime.window.showPanel(key)
end

-- Whether the window is shown on that registered panel. Internal callers use
-- this, not api.IsPanelShown, which another addon can overwrite.
function Panels.IsShown(runtime, key)
  if not isKnown(runtime, key) or not runtime.isWindowVisible() then
    return false
  end
  local window = runtime.window
  return window ~= nil and window.getVisiblePanel() == key
end

function Panels.Install(api, runtime)
  local function isPanelShown(key)
    return Panels.IsShown(runtime, key)
  end

  local function showPanel(key)
    return Panels.Open(runtime, key)
  end

  api.RegisterPanel = Guards.Wrap(function(key, panel)
    local spec = copyPanel(panel)
    if not Guards.IsNonEmptyString(key) or not isValidPanel(spec) then
      return false
    end
    if not runtime.panelRegistry.register(key, spec) then
      return false
    end
    refreshIcons(runtime)
    return true
  end)

  api.ShowPanel = Guards.Wrap(showPanel)

  api.TogglePanel = Guards.Wrap(function(key)
    if not isPanelShown(key) then
      return showPanel(key)
    end
    runtime.window.hidePanel(true)
    runtime.setWindowVisible(false)
    return true
  end)

  api.IsPanelShown = Guards.Wrap(isPanelShown)

  api.RefreshPanelBadge = Guards.Wrap(function(key)
    if not isKnown(runtime, key) then
      return false
    end
    if runtime.window ~= nil then
      runtime.window.refreshPanelBadge(key)
    end
    refreshIcons(runtime)
    return true
  end)
end

ns.PublicApiPanels = Panels
return Panels
