local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PanelBadge = ns.PanelBadge or require("WhisperMessenger.UI.Shared.PanelBadge")

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

  -- Read the way the panel's tab reads it, so the numbers agree.
  local function readBadge(key)
    return PanelBadge.Read(panels[key].badge)
  end

  -- What the panels add to the icon number.
  local function badgeSum()
    local sum = 0
    for _, key in ipairs(order) do
      sum = sum + readBadge(key)
    end
    return sum
  end

  -- The first panel, in registration order, with something waiting.
  local function firstBadgedKey()
    for _, key in ipairs(order) do
      if readBadge(key) > 0 then
        return key
      end
    end
    return nil
  end

  -- The player marked everything read: tell each panel, in registration
  -- order (one panel's error stops no other), then re-read the tab badges.
  local function markAllRead()
    for _, key in ipairs(order) do
      local callback = panels[key].onMarkAllRead
      if callback ~= nil then
        pcall(callback)
      end
    end
    if window == nil or window.refreshPanelBadge == nil then
      return
    end
    for _, key in ipairs(order) do
      pcall(window.refreshPanelBadge, key)
    end
  end

  return {
    register = register,
    markAllRead = markAllRead,
    badgeSum = badgeSum,
    firstBadgedKey = firstBadgedKey,
    get = function(key)
      return panels[key]
    end,
    bind = bind,
  }
end

ns.BootstrapWindowRuntimePanelRegistry = PanelRegistry
return PanelRegistry
