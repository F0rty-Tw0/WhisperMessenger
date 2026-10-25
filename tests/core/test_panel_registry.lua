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

  -- test_get_unknown_is_nil
  assert(PanelRegistry.New().get("nope") == nil)
end
