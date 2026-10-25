local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")

local function makeWindow(result)
  local window = { registered = {} }
  window.registerPanel = function(key, panel)
    window.registered[#window.registered + 1] = { key = key, panel = panel }
    return result ~= false
  end
  return window
end

return function()
  -- test_register_before_bind_stores
  do
    local registry = PanelRegistry.New()
    local panel = { title = "A" }
    assert(registry.register("a", panel) == true)
    assert(registry.get("a") == panel)
  end

  -- test_bind_registers_each_in_order
  do
    local registry = PanelRegistry.New()
    local a, b = {}, {}
    registry.register("a", a)
    registry.register("b", b)
    local window = makeWindow()
    registry.bind(window)
    assert(#window.registered == 2, "both panels registered")
    assert(window.registered[1].key == "a" and window.registered[1].panel == a)
    assert(window.registered[2].key == "b" and window.registered[2].panel == b)
  end

  -- test_register_after_bind_applies_immediately
  do
    local registry = PanelRegistry.New()
    local window = makeWindow()
    registry.bind(window)
    assert(registry.register("c", {}) == true)
    assert(#window.registered == 1 and window.registered[1].key == "c")
  end

  -- test_duplicate_key_is_refused
  do
    local registry = PanelRegistry.New()
    local first = {}
    registry.register("a", first)
    assert(registry.register("a", {}) == false)
    assert(registry.get("a") == first, "first registration wins")
  end

  -- test_window_refusal_is_not_kept
  do
    local registry = PanelRegistry.New()
    registry.bind(makeWindow(false))
    assert(registry.register("a", {}) == false)
    assert(registry.get("a") == nil, "refused key not kept")
  end

  -- test_mark_all_read_calls_each_panel_in_registration_order
  do
    local registry = PanelRegistry.New()
    local seen = {}
    registry.register("a", {
      onMarkAllRead = function()
        seen[#seen + 1] = "a"
      end,
    })
    registry.register("quiet", {})
    registry.register("b", {
      onMarkAllRead = function()
        seen[#seen + 1] = "b"
      end,
    })
    registry.markAllRead()
    assert(table.concat(seen, ",") == "a,b", "got: " .. table.concat(seen, ","))
  end

  -- test_mark_all_read_survives_a_throwing_panel
  do
    local registry = PanelRegistry.New()
    local reached = false
    registry.register("bad", {
      onMarkAllRead = function()
        error("addon bug")
      end,
    })
    registry.register("good", {
      onMarkAllRead = function()
        reached = true
      end,
    })
    registry.markAllRead()
    assert(reached, "the next panel still runs")
  end

  -- test_get_unknown_is_nil
  assert(PanelRegistry.New().get("nope") == nil)
end
