local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local EventUtils = ns.EventUtils or require("WhisperMessenger.Core.EventUtils")

local AddonEventFrame = {}

local function resolveModule(currentValue, namespaceKey, loadModule, moduleName, moduleKey)
  if currentValue then
    return currentValue
  end

  return ns[namespaceKey] or loadModule(moduleName, moduleKey)
end

function AddonEventFrame.Install(deps)
  deps = deps or {}

  local Bootstrap = deps.Bootstrap or {}
  local createFrame = deps.createFrame or _G.CreateFrame
  if type(createFrame) ~= "function" then
    return nil
  end

  local loadModule = deps.loadModule
    or function(name, key)
      error((key or name or "module") .. " module not available")
    end
  local initializeRuntime = deps.initializeRuntime or function()
    return Bootstrap.runtime
  end
  local trace = deps.trace or function(...)
    local _ = ...
  end
  local targetAddonName = deps.addonName or addonName

  local loadFrame = createFrame("Frame", "WhisperMessengerLoadFrame")
  Bootstrap._loadFrame = loadFrame

  local EventBridge = ns.BootstrapEventBridge
  local LifecycleHandlers = ns.BootstrapLifecycleHandlers

  loadFrame:RegisterEvent("ADDON_LOADED")
  loadFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
      local loadedAddonName = ...
      if loadedAddonName ~= targetAddonName then
        return
      end

      trace("ADDON_LOADED", loadedAddonName)
      initializeRuntime()

      EventBridge = resolveModule(
        EventBridge,
        "BootstrapEventBridge",
        loadModule,
        "WhisperMessenger.Core.Bootstrap.EventBridge",
        "BootstrapEventBridge"
      )
      EventBridge.RegisterLiveEvents(loadFrame)
      EventBridge.RegisterChannelEvents(loadFrame)

      local runtime = Bootstrap.runtime
      if runtime and runtime.autoOpenCoordinator then
        runtime.autoOpenCoordinator.installDeferredPoller()
      end

      local Constants = loadModule("WhisperMessenger.Core.Constants", "Constants")
      for _, eventName in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
        EventUtils.RegisterEventIfSupported(loadFrame, eventName)
      end

      if loadFrame.UnregisterEvent then
        loadFrame:UnregisterEvent("ADDON_LOADED")
      end

      return
    end

    -- Route channel messages directly to the store (bypass whisper pipeline)
    EventBridge = resolveModule(
      EventBridge,
      "BootstrapEventBridge",
      loadModule,
      "WhisperMessenger.Core.Bootstrap.EventBridge",
      "BootstrapEventBridge"
    )
    if EventBridge and EventBridge.RouteChannelEvent then
      local runtime = Bootstrap.runtime
      if EventBridge.RouteChannelEvent(runtime, event, ...) then
        return
      end
    end

    LifecycleHandlers = resolveModule(
      LifecycleHandlers,
      "BootstrapLifecycleHandlers",
      loadModule,
      "WhisperMessenger.Core.Bootstrap.LifecycleHandlers",
      "BootstrapLifecycleHandlers"
    )
    if
      LifecycleHandlers
      and LifecycleHandlers.Handle(Bootstrap, event, {
        loadModule = loadModule,
        trace = trace,
        getContentDetector = function()
          return ns.ContentDetector
        end,
        getPresenceCache = function()
          return ns.PresenceCache
        end,
      }, ...)
    then
      return
    end

    if Bootstrap._inMythicContent then
      return
    end

    EventBridge = resolveModule(
      EventBridge,
      "BootstrapEventBridge",
      loadModule,
      "WhisperMessenger.Core.Bootstrap.EventBridge",
      "BootstrapEventBridge"
    )
    if EventBridge then
      local runtime = Bootstrap.runtime
      EventBridge.RouteLiveEvent(runtime, runtime and runtime.refreshWindow or nil, event, ...)
    end
  end)

  return loadFrame
end

ns.BootstrapAddonEventFrame = AddonEventFrame
return AddonEventFrame
