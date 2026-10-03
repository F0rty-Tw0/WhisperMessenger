local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Shared by the modern and Native WoW HUD tabs that hang below the window:
-- which modes are visible, the active mode, unread counts and the screen
-- clamp over the hanging strip.
local TabLayout = {}

TabLayout.MODES = { "whispers", "groups", "channels", "requests" }

local DEFAULT_MODES = { "whispers", "groups" }

-- tabs: { whispers = tab, groups = tab, channels = tab, requests = tab },
-- each with `.btn`.
-- Returns the visible tabs in MODES order.
function TabLayout.VisibleTabs(tabs, modes)
  local wanted = {}
  for _, mode in ipairs(modes or DEFAULT_MODES) do
    wanted[mode] = true
  end
  local visible = {}
  for _, mode in ipairs(TabLayout.MODES) do
    local tab = tabs[mode]
    if tab then
      tab.btn:SetShown(wanted[mode] == true)
      if wanted[mode] then
        visible[#visible + 1] = tab
      end
    end
  end
  return visible
end

-- Tabs hanging below the window: returns applyClamp(shown), which extends
-- the window's screen clamp down by hangHeight while they show. The window's
-- own insets are kept and restored when they hide.
function TabLayout.BindClamp(window, hangHeight)
  if not (window.SetClampRectInsets and window.GetClampRectInsets) then
    return function(_shown) end
  end
  local left, right, top, bottom = window:GetClampRectInsets()
  return function(shown)
    window:SetClampRectInsets(left, right, top, shown and bottom - hangHeight or bottom)
  end
end

-- A mode that is no longer visible falls back to Whispers.
function TabLayout.ResolveMode(mode, visible)
  for _, tab in ipairs(visible) do
    if tab.mode == mode then
      return mode
    end
  end
  return "whispers"
end

-- Mode and unread controller shared by both tab skins. Sets setMode,
-- getMode, setModes, setShown, setUnreadCounts and setLanguage on toggle,
-- binds each tab's OnClick, and returns the paint function (for hover
-- handlers).
--
-- tabsByMode: one tab per TabLayout.MODES entry; each tab has
-- `.btn`, `.mode` and a writable `.unread`.
-- opts:
--   initialMode, onModeChanged(mode)
--   paint(mode, visible)
--   relabel(tab)       : re-reads the tab's label from the active locale
--   anchor(visible)    : places the visible tab buttons
function TabLayout.BindController(toggle, frame, tabsByMode, opts)
  local onModeChanged = opts.onModeChanged or function(_mode) end
  local currentMode = opts.initialMode or "whispers"
  local visibleModes = nil
  local visible = {}

  local function paint()
    opts.paint(currentMode, visible)
  end

  local function setMode(mode)
    currentMode = TabLayout.ResolveMode(mode, visible)
    paint()
  end

  local function relayout()
    visible = TabLayout.VisibleTabs(tabsByMode, visibleModes)
    opts.anchor(visible)
  end

  relayout()
  for _, mode in ipairs(TabLayout.MODES) do
    tabsByMode[mode].btn:SetScript("OnClick", function()
      if currentMode ~= mode then
        setMode(mode)
        onModeChanged(mode)
      end
    end)
  end
  paint()

  toggle.setMode = setMode
  toggle.getMode = function()
    return currentMode
  end
  -- modes: visible tabs, e.g. { "whispers", "groups", "channels", "requests" }.
  toggle.setModes = function(modes)
    visibleModes = modes
    relayout()
    setMode(currentMode)
  end
  toggle.setShown = function(shown)
    frame:SetShown(shown)
  end
  toggle.setUnreadCounts = function(whispersCount, groupsCount, requestsCount, channelsCount)
    tabsByMode.whispers.unread = tonumber(whispersCount) or 0
    tabsByMode.groups.unread = tonumber(groupsCount) or 0
    tabsByMode.requests.unread = tonumber(requestsCount) or 0
    tabsByMode.channels.unread = tonumber(channelsCount) or 0
    paint()
  end
  toggle.setLanguage = function()
    for _, mode in ipairs(TabLayout.MODES) do
      opts.relabel(tabsByMode[mode])
    end
    -- Label widths changed: re-place the tabs.
    opts.anchor(visible)
    paint()
  end
  return paint
end

ns.ContactsListTabLayout = TabLayout
return TabLayout
