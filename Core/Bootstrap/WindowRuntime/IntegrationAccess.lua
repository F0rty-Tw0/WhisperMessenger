local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local ContactInfo = ns.ContactInfo or require("WhisperMessenger.Model.ContactInfo")
local ReloadPrompt = ns.ReloadPrompt or require("WhisperMessenger.UI.Shared.ReloadPrompt")

-- Applies a tick change on the Addons page at once: a refused addon's tab,
-- preview and notes go; an allowed one's tab comes back. A row that connected
-- refused has no handle in this session, so ticking it asks for a reload.
local IntegrationAccess = {}

local QUESTION = "Reload the interface now to apply the addon integration change?"

local function text(key)
  return Localization and Localization.Text(key) or key
end

-- Each step runs alone: one raising step stops no other.
local function step(fn, ...)
  pcall(fn, ...)
end

local function hideOpenPanel(runtime, panelKeys)
  local window = runtime.window
  if not window then
    return
  end
  local open = window.getVisiblePanel()
  for _, key in ipairs(panelKeys) do
    if key == open then
      window.hidePanel()
    end
  end
end

local function applyPanels(runtime, panelKeys)
  for _, key in ipairs(panelKeys) do
    step(runtime.panelRegistry.applyActive, key)
  end
end

-- The tab was hidden while the panel kept counting: re-read its badge.
local function refreshBadges(runtime, panelKeys)
  local window = runtime.window
  if not window or not window.refreshPanelBadge then
    return
  end
  for _, key in ipairs(panelKeys) do
    step(window.refreshPanelBadge, key)
  end
end

local function clearPreviews(runtime, registry, name)
  for _, key in ipairs(registry.ownedBy("preview", name)) do
    step(runtime.externalPreview.clear, key)
  end
end

local function clearNotes(runtime, registry, name)
  for _, key in ipairs(registry.ownedBy("note", name)) do
    step(ContactInfo.ClearSource, runtime.contactInfo, key)
  end
end

local function refreshSurfaces(runtime)
  step(runtime.updateIconSurfaces)
  if runtime.isWindowVisible() then
    step(runtime.refreshWindow)
  end
end

local function onRefused(runtime, registry, name)
  local panelKeys = registry.ownedBy("panel", name)
  step(hideOpenPanel, runtime, panelKeys)
  step(applyPanels, runtime, panelKeys)
  step(clearPreviews, runtime, registry, name)
  step(clearNotes, runtime, registry, name)
  step(refreshSurfaces, runtime)
end

local function onAllowed(runtime, registry, name)
  local panelKeys = registry.ownedBy("panel", name)
  step(applyPanels, runtime, panelKeys)
  step(refreshBadges, runtime, panelKeys)
  step(runtime.updateIconSurfaces)
  if registry.connectedRefused(name) then
    step(ReloadPrompt.Show, text(QUESTION), nil, nil)
  end
end

function IntegrationAccess.Attach(runtime)
  local registry = runtime.addonIntegrations
  if not registry then
    return
  end
  registry.onChange(function(event, name)
    if event == "refused" then
      onRefused(runtime, registry, name)
    elseif event == "allowed" then
      onAllowed(runtime, registry, name)
    end
  end)
end

ns.BootstrapWindowRuntimeIntegrationAccess = IntegrationAccess
return IntegrationAccess
