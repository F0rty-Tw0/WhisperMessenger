local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local Panels = ns.PublicApiPanels or require("WhisperMessenger.Core.PublicApi.Panels")
local WhoTriggers = ns.BootstrapWindowRuntimeWhoTriggers or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhoTriggers")

-- The click handler for the widget, minimap and LDB icons. The Toggle Window
-- key asks /who through runtime.toggleTargetKey (Core/Bindings.lua); /wmsg
-- keeps the plain toggle.
local IconToggle = {}

-- Where the previews show: the detached card while the runtime reports one,
-- else the widget icon (nil in minimap mode).
local function activeSurface(runtime)
  if runtime.getActivePreviewSurface then
    return runtime.getActivePreviewSurface()
  end
  return runtime.getWidgetIcon and runtime.getWidgetIcon() or nil
end

-- The owner of the preview the active surface shows; nil when no preview is on
-- screen (no surface in this icon mode, or the frame hidden), since the slot
-- keeps its entry after the surface stops showing it.
local function shownPreviewKey(runtime)
  local surface = activeSurface(runtime)
  if surface == nil or surface.isExternalPreviewShown == nil or not surface.isExternalPreviewShown() then
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

-- The active surface's whisper card on screen opens its chat, as a click on
-- the card would. False when no such card shows, the open was refused, or the
-- widget sits docked on the window (it hides its card, even while the detached
-- card could open).
local function openShownWhisperPreview(runtime)
  local widget = runtime.getWidgetIcon and runtime.getWidgetIcon() or nil
  if widget ~= nil and widget.isRiding ~= nil and widget.isRiding() then
    return false
  end
  local surface = activeSurface(runtime)
  return surface ~= nil and surface.openShownPreview ~= nil and surface.openShownPreview() == true
end

-- A whisper card on the active surface opens its chat. The button docked on an
-- open window hides its card, so a click there closes the window instead.
-- Otherwise a visible window hides, other whispers run the plain toggle, and an addon page with
-- something waiting opens; with no such page, or when opening it is refused,
-- the plain toggle runs. A toggle that opens onto a chat gets a /who for that
-- chat first, inside this click and before the window opens: openTargetKey
-- names the chat the toggle will select (nil: none, or no resolver, no ask).
function IconToggle.Wrap(runtime, toggle, buildContacts, openTargetKey)
  local function open()
    local targetKey = openTargetKey and openTargetKey()
    if targetKey ~= nil then
      WhoTriggers.AskFor(runtime, targetKey)
    end

    return toggle()
  end

  return function()
    if openShownWhisperPreview(runtime) then
      return
    end
    if runtime.isWindowVisible() then
      return toggle()
    end
    if BadgeFilter.SumWhisperUnread(buildContacts()) > 0 then
      return open()
    end
    local key = targetPanelKey(runtime)
    if key ~= nil and Panels.Open(runtime, key) then
      return
    end
    -- No target or a refused open changed nothing; a failed showPanel left
    -- the window open, so it must not be toggled shut.
    if not runtime.isWindowVisible() then
      return open()
    end
  end
end

ns.BootstrapWindowRuntimeIconToggle = IconToggle
return IconToggle
