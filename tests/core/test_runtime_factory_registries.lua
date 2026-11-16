local RuntimeBindings = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RuntimeBindings")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local SavedState = require("WhisperMessenger.Persistence.SavedState")

-- The panel registry and the contact notes exist from the moment the runtime
-- does, so nothing built later can run before them.
local function newRuntime()
  local accountState, characterState = SavedState.Initialize(nil, nil, "me")
  return RuntimeFactory.CreateRuntimeState(accountState, characterState, "me", {})
end

return function()
  -- test_factory_creates_the_panel_registry_and_contact_info
  do
    local runtime = newRuntime()
    assert(type(runtime.panelRegistry) == "table", "the panel registry must exist before the window runtime is built")
    assert(runtime.panelRegistry.badgeSum() == 0, "an empty registry adds nothing to the icon number")
    assert(type(runtime.contactInfo) == "table", "the contact notes must exist before the window runtime is built")
  end

  -- test_binding_the_window_runtime_keeps_the_factory_registries
  do
    local runtime = newRuntime()
    local registry, contactInfo = runtime.panelRegistry, runtime.contactInfo
    RuntimeBindings.Apply({ runtime = runtime })
    assert(runtime.panelRegistry == registry, "binding must not replace the panel registry")
    assert(runtime.contactInfo == contactInfo, "binding must not replace the contact notes")
  end

  -- test_panel_registry_asks_the_integration_registry_at_call_time
  do
    local allowed = { CraftAlert = true }
    local runtime = newRuntime()
    assert(runtime.panelRegistry.isActive("ca") == true, "no registry yet: active")
    runtime.addonIntegrations = {
      ownerOf = function(kind, key)
        assert(kind == "panel")
        return key == "ca" and "CraftAlert" or nil
      end,
      isAllowed = function(name)
        return allowed[name]
      end,
    }
    assert(runtime.panelRegistry.isActive("ca") == true)
    allowed.CraftAlert = false
    assert(runtime.panelRegistry.isActive("ca") == false, "owner refused")
    assert(runtime.panelRegistry.isActive("unowned") == true, "unowned panels stay active")
  end
end
