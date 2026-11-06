local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local Panels = require("WhisperMessenger.Core.PublicApi.Panels")

local function noop() end

local function with(overrides)
  local p = { title = "Alerts", onShow = noop }
  for k, v in pairs(overrides or {}) do
    p[k] = v
  end
  return p
end

-- RegisterPanel on a runtime whose window records the table it is handed.
local function build()
  local runtime = { panelRegistry = PanelRegistry.New(), handed = {} }
  runtime.panelRegistry.bind({
    registerPanel = function(key, panel)
      runtime.handed[key] = panel
      return true
    end,
  })
  local api = {}
  Panels.Install(api, runtime)
  return api, runtime
end

return function()
  -- test_register_accepts_a_boolean_compact_and_refuses_other_types
  do
    local api = build()
    assert(api.RegisterPanel("t", with({ compact = true })) == true, "compact = true")
    assert(api.RegisterPanel("f", with({ compact = false })) == true, "compact = false")
    assert(api.RegisterPanel("n", with()) == true, "compact left out")
    assert(api.RegisterPanel("s", with({ compact = "yes" })) == false, "compact = a string")
    assert(api.RegisterPanel("i", with({ compact = 1 })) == false, "compact = a number")
    assert(api.RegisterPanel("t2", with({ compact = {} })) == false, "compact = a table")
  end

  -- test_the_registry_copy_keeps_compact_and_the_window_gets_that_copy
  do
    local api, r = build()
    local panel = with({ compact = true })
    assert(api.RegisterPanel("ca", panel) == true)
    panel.compact = false
    local stored = r.panelRegistry.get("ca")
    assert(stored.compact == true, "a later change to the caller's table does not reach the copy")
    assert(r.handed.ca == stored and r.handed.ca ~= panel, "the window host is handed the registry's copy, not the caller's table")
  end

  -- test_a_panel_without_compact_is_stored_without_it
  do
    local api, r = build()
    assert(api.RegisterPanel("ca", with()) == true)
    assert(r.panelRegistry.get("ca").compact == nil)
  end
end
