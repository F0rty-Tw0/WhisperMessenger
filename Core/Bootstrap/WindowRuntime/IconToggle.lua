local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local Panels = ns.PublicApiPanels or require("WhisperMessenger.Core.PublicApi.Panels")

-- The click handler for the widget, minimap and LDB icons. Keybinds and slash
-- commands keep the plain toggle.
local IconToggle = {}

-- The owner of the preview the widget shows; nil when no preview is on
-- screen (no widget in this icon mode, or the frame hidden), since the slot
-- keeps its entry after the widget stops showing it.
local function shownPreviewKey(runtime)
  local widget = runtime.getWidgetIcon and runtime.getWidgetIcon() or nil
  if widget == nil or widget.isExternalPreviewShown == nil or not widget.isExternalPreviewShown() then
    return nil
  end
  return runtime.externalPreview and runtime.externalPreview.keyOf() or nil
end

-- The panel of the addon whose preview is on the widget, else the first
-- panel with a badge. Read at click time: the registry and preview exist only
-- once the runtime is bound.
local function targetPanelKey(runtime)
  local registry = runtime.panelRegistry
  local ownerKey = shownPreviewKey(runtime)
  if ownerKey ~= nil and registry.get(ownerKey) ~= nil then
    return ownerKey
  end
  return registry.firstBadgedKey()
end

-- Whispers win, and a visible window still hides. Otherwise an addon page
-- with something waiting opens; with no such page, or when opening it is
-- refused, the plain toggle runs.
function IconToggle.Wrap(runtime, toggle, buildContacts)
  return function()
    if runtime.isWindowVisible() or BadgeFilter.SumWhisperUnread(buildContacts()) > 0 then
      return toggle()
    end
    local key = targetPanelKey(runtime)
    if key ~= nil and Panels.Open(runtime, key) then
      return
    end
    -- No target or a refused open changed nothing; a failed showPanel left
    -- the window open, so it must not be toggled shut.
    if not runtime.isWindowVisible() then
      return toggle()
    end
  end
end

ns.BootstrapWindowRuntimeIconToggle = IconToggle
return IconToggle
