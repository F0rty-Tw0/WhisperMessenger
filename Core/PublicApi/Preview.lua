local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local Panels = ns.PublicApiPanels or require("WhisperMessenger.Core.PublicApi.Panels")
local DetachedPreviewRuntime = ns.BootstrapWindowRuntimeDetachedPreviewRuntime
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.DetachedPreviewRuntime")

-- ShowPreview / HidePreview / IsPreviewShown: another addon's preview on the
-- widget. One slot; a newer caller replaces the older one silently.
-- preview.pulse (optional boolean): the widget glows while the preview shows,
-- until the player opens the owner's panel (the panel registered under the
-- same key as sourceKey). Every ShowPreview arms it again, unless that panel
-- is showing at that moment.
-- preview.detail (optional string): a third line under the text; empty or
-- missing keeps the two-line preview.
local Preview = {}

-- Same answer as api.IsPanelShown (false on any error), read off the module
-- so another addon cannot swap it.
local isPanelShown = Guards.Wrap(Panels.IsShown)

local function isOptional(value, kind)
  return value == nil or type(value) == kind
end

local function isValidPreview(preview)
  return type(preview) == "table"
    and Guards.IsNonEmptyString(preview.sender)
    and Guards.IsNonEmptyString(preview.text)
    and isOptional(preview.classTag, "string")
    and isOptional(preview.detail, "string")
    and isOptional(preview.onClick, "function")
    and isOptional(preview.onDismiss, "function")
    and isOptional(preview.onShown, "function")
    and isOptional(preview.pulse, "boolean")
end

local function previewsTurnedOff(runtime)
  local settings = runtime.accountState and runtime.accountState.settings
  return settings ~= nil and settings.showWidgetMessagePreview == false
end

-- On the compact window the button hides every card, so a true here would tell
-- the caller "shown" while the player sees nothing; false keeps its own toast.
local function buttonRidesWindow(icon)
  return icon.isRiding ~= nil and icon.isRiding() == true
end

-- Where the previews show: the detached card when the runtime reports one,
-- else the widget icon (nil in minimap mode).
local function activeSurface(runtime)
  if runtime.getActivePreviewSurface then
    return runtime.getActivePreviewSurface()
  end
  return runtime.getWidgetIcon and runtime.getWidgetIcon() or nil
end

-- The detached card shows with or without a widget, and does not ride the
-- window, so only the setting and an existing card decide.
local function showsDetached(runtime)
  return DetachedPreviewRuntime.IsDetached(runtime.accountState and runtime.accountState.settings)
    and runtime.getActivePreviewSurface ~= nil
    and runtime.getActivePreviewSurface() ~= nil
end

local function previewRefused(runtime)
  if previewsTurnedOff(runtime) then
    return true
  end
  if showsDetached(runtime) then
    return false
  end
  local icon = runtime.getWidgetIcon()
  return icon == nil or buttonRidesWindow(icon)
end

function Preview.Install(api, runtime)
  api.ShowPreview = Guards.Wrap(function(sourceKey, preview)
    if not Guards.IsNonEmptyString(sourceKey) or not isValidPreview(preview) then
      return false
    end
    if previewRefused(runtime) then
      return false
    end
    runtime.externalPreview.set(sourceKey, preview, isPanelShown(runtime, sourceKey))
    Guards.Claim(runtime, "preview", sourceKey)
    runtime.updateIconSurfaces()
    return true
  end)

  api.HidePreview = Guards.Wrap(function(sourceKey)
    if not Guards.IsNonEmptyString(sourceKey) or not runtime.externalPreview.clear(sourceKey) then
      return false
    end
    runtime.updateIconSurfaces()
    return true
  end)

  api.IsPreviewShown = Guards.Wrap(function(sourceKey)
    if not Guards.IsNonEmptyString(sourceKey) or runtime.externalPreview.keyOf() ~= sourceKey then
      return false
    end
    local surface = activeSurface(runtime)
    return surface ~= nil and surface.isExternalPreviewShown ~= nil and surface.isExternalPreviewShown()
  end)
end

ns.PublicApiPreview = Preview
return Preview
