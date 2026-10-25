local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")

-- RegisterPanel / ShowPanel / TogglePanel / IsPanelShown / RefreshPanelBadge:
-- another addon's panel in the messenger window, opened from its own
-- title-bar button. The first registration of a key wins.
local Panels = {}

local function isOptionalFunction(value)
  return value == nil or type(value) == "function"
end

local function isValidPanel(panel)
  return type(panel) == "table"
    and Guards.IsNonEmptyString(panel.title)
    and (type(panel.icon) == "string" or type(panel.icon) == "number")
    and type(panel.onShow) == "function"
    and isOptionalFunction(panel.onHide)
    and isOptionalFunction(panel.badge)
end

-- The registry keeps this copy, read once: a caller that changes its table
-- later cannot break the button, tooltip or window build.
local function copyPanel(panel)
  if type(panel) ~= "table" then
    return nil
  end
  return { title = panel.title, icon = panel.icon, onShow = panel.onShow, onHide = panel.onHide, badge = panel.badge }
end

local function isKnown(runtime, key)
  return Guards.IsNonEmptyString(key) and runtime.panelRegistry.get(key) ~= nil
end

function Panels.Install(api, runtime)
  local function isPanelShown(key)
    if not isKnown(runtime, key) or not runtime.isWindowVisible() then
      return false
    end
    local window = runtime.window
    return window ~= nil and window.getVisiblePanel() == key
  end

  local function showPanel(key)
    if not isKnown(runtime, key) or Guards.IsRefused(runtime) then
      return false
    end
    runtime.ensureWindow()
    runtime.setWindowVisible(true)
    return runtime.window.showPanel(key)
  end

  api.RegisterPanel = Guards.Wrap(function(key, panel)
    local spec = copyPanel(panel)
    if not Guards.IsNonEmptyString(key) or not isValidPanel(spec) then
      return false
    end
    return runtime.panelRegistry.register(key, spec)
  end)

  api.ShowPanel = Guards.Wrap(showPanel)

  api.TogglePanel = Guards.Wrap(function(key)
    if not isPanelShown(key) then
      return showPanel(key)
    end
    runtime.window.hidePanel()
    runtime.setWindowVisible(false)
    return true
  end)

  api.IsPanelShown = Guards.Wrap(isPanelShown)

  api.RefreshPanelBadge = Guards.Wrap(function(key)
    if not isKnown(runtime, key) then
      return false
    end
    if runtime.window ~= nil then
      runtime.window.refreshPanelBadge(key)
    end
    return true
  end)
end

ns.PublicApiPanels = Panels
return Panels
