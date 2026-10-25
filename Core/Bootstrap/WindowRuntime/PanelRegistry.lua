local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Keeps the panels other addons register before the window exists (it is
-- built on first open) and hands them to it, in registration order, once it
-- does. After that a registration goes straight to the window.
local PanelRegistry = {}

function PanelRegistry.New()
  local panels = {}
  local order = {}
  local window = nil

  local function register(key, panel)
    if panels[key] ~= nil then
      return false
    end
    if window ~= nil and not window.registerPanel(key, panel) then
      return false
    end
    panels[key] = panel
    order[#order + 1] = key
    return true
  end

  local function bind(nextWindow)
    window = nextWindow
    for _, key in ipairs(order) do
      window.registerPanel(key, panels[key])
    end
  end

  return {
    register = register,
    get = function(key)
      return panels[key]
    end,
    bind = bind,
  }
end

ns.BootstrapWindowRuntimePanelRegistry = PanelRegistry
return PanelRegistry
