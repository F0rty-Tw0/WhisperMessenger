local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local Panels = require("WhisperMessenger.Core.PublicApi.Panels")

local function makeRuntime(registry)
  local log = {}
  local runtime = { panelRegistry = registry }
  runtime.isCompetitiveContent = function()
    return false
  end
  runtime.isMythicLockdown = function()
    return false
  end
  runtime.isWindowVisible = function()
    return false
  end
  runtime.ensureWindow = function()
    log[#log + 1] = "ensure"
    runtime.window = {
      showPanel = function(key)
        log[#log + 1] = "show:" .. key
        return true
      end,
    }
  end
  runtime.setWindowVisible = function(visible)
    log[#log + 1] = "visible:" .. tostring(visible)
  end
  return runtime, log
end

return function()
  -- test_open_refuses_an_inactive_panel
  do
    local registry = PanelRegistry.New({
      isActive = function()
        return false
      end,
    })
    registry.register("ca", { title = "Alerts", onShow = function() end })
    local runtime, log = makeRuntime(registry)
    assert(Panels.Open(runtime, "ca") == false)
    assert(#log == 0, "nothing opened, got " .. table.concat(log, ","))
  end

  -- test_open_still_works_for_an_active_panel
  do
    local registry = PanelRegistry.New()
    registry.register("ca", { title = "Alerts", onShow = function() end })
    local runtime, log = makeRuntime(registry)
    assert(Panels.Open(runtime, "ca") == true)
    assert(log[#log] == "show:ca")
  end

  -- test_open_works_with_a_registry_that_has_no_is_active
  do
    local runtime, log = makeRuntime({
      get = function()
        return {}
      end,
    })
    assert(Panels.Open(runtime, "ca") == true and log[#log] == "show:ca")
  end
end
