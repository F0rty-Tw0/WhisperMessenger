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
-- own bottom inset is restored when they hide; the other edges are not ours,
-- so they are read at each call.
function TabLayout.BindClamp(window, hangHeight)
  if not (window.SetClampRectInsets and window.GetClampRectInsets) then
    return function(_shown) end
  end
  local _, _, _, bottom = window:GetClampRectInsets()
  return function(shown)
    local left, right, top = window:GetClampRectInsets()
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

-- While an addon panel is selected only its tab paints selected; otherwise
-- the tab of the current mode does.
function TabLayout.IsActive(tab, currentMode, selectedPanel)
  if selectedPanel ~= nil then
    return tab.panelKey == selectedPanel
  end
  return tab.mode == currentMode
end

local NO_PANEL_TAB = {
  setBadge = function(_count) end,
}

-- Mode and unread controller shared by both tab skins. Sets setMode,
-- getMode, setModes, setShown, setOptionsShown, setUnreadCounts,
-- setLanguage, addPanelTab, setPanelTabShown, setSelectedPanel,
-- getSelectedPanel, setModeClickHandler and setCurrentModeClickHandler on
-- toggle, binds each tab's OnClick, and returns the paint function (for hover
-- handlers). The strip shows while more than one tab is visible and the
-- options page is closed; setModes, addPanelTab, setPanelTabShown and
-- setOptionsShown apply that through toggle.setShown.
--
-- tabsByMode: one tab per TabLayout.MODES entry; each tab has
-- `.btn`, `.mode` and a writable `.unread`.
-- opts:
--   initialMode, onModeChanged(mode)
--   paint(mode, visible, selectedPanel, panelTabs)
--   relabel(tab)       : re-reads a mode tab's label from the active locale
--   anchor(visible, activeTab) : places the visible tab buttons (mode + panel
--                        tabs); activeTab is the one painted selected, or nil
--   createPanelTab(title, index) : an addon panel tab with `.btn`, `.badge`
--                        and a writable `.unread`, or nil
function TabLayout.BindController(toggle, frame, tabsByMode, opts)
  local onModeChanged = opts.onModeChanged or function(_mode) end
  local currentMode = opts.initialMode or "whispers"
  local visibleModes = nil
  local visible = {}
  local panelTabs = {}
  local selectedPanel = nil
  local modeClickHandler = nil
  local currentModeClickHandler = nil
  local optionsShown = false
  local lastActive = nil
  -- Set while a mode click's panel handler runs (see the tab OnClick).
  local holdAnchor = false

  local function paint()
    opts.paint(currentMode, visible, selectedPanel, panelTabs)
  end

  local function activeTab()
    for _, tab in ipairs(visible) do
      if TabLayout.IsActive(tab, currentMode, selectedPanel) then
        return tab
      end
    end
    return nil
  end

  local function anchor()
    lastActive = activeTab()
    opts.anchor(visible, lastActive)
  end

  -- A repaint-only update (theme refresh) leaves the skin's scroll alone.
  local function anchorIfActiveChanged()
    if not holdAnchor and activeTab() ~= lastActive then
      anchor()
    end
  end

  -- Through toggle.setShown looked up now, so the skin's clamp wrapper runs.
  local function applyShown()
    toggle.setShown(#visible > 1 and not optionsShown)
  end

  local function setMode(mode)
    currentMode = TabLayout.ResolveMode(mode, visible)
    paint()
    anchorIfActiveChanged()
  end

  -- Panel tabs always follow the visible mode tabs; a hidden one is skipped.
  local function relayout()
    visible = TabLayout.VisibleTabs(tabsByMode, visibleModes)
    for _, tab in ipairs(panelTabs) do
      if not tab.hidden then
        visible[#visible + 1] = tab
      end
    end
    anchor()
  end

  relayout()
  for _, mode in ipairs(TabLayout.MODES) do
    tabsByMode[mode].btn:SetScript("OnClick", function()
      -- Leaving a panel runs even for the current mode's tab. Read before
      -- the handler: it clears selectedPanel.
      local hadPanel = selectedPanel ~= nil
      if hadPanel and modeClickHandler then
        -- The handler leaves the panel; anchoring the old mode's tab then
        -- would scroll it in and push the clicked tab a slot.
        holdAnchor = true
        local ok, err = pcall(modeClickHandler, mode)
        holdAnchor = false
        if not ok then
          error(err, 0)
        end
      end
      if currentMode ~= mode then
        setMode(mode)
        onModeChanged(mode)
      elseif not hadPanel and currentModeClickHandler then
        currentModeClickHandler()
      end
      anchorIfActiveChanged()
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
    applyShown()
  end
  toggle.setShown = function(shown)
    frame:SetShown(shown)
  end
  -- The options page covers the panes; the strip hides under it.
  toggle.setOptionsShown = function(shown)
    optionsShown = shown == true
    applyShown()
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
    anchor()
    paint()
  end
  -- An addon panel's tab, after the mode tabs in registration order. The
  -- title is shown as given, never translated.
  toggle.addPanelTab = function(key, title, onClick)
    local tab = opts.createPanelTab(title, #panelTabs + 1)
    if tab == nil then
      return NO_PANEL_TAB
    end
    tab.panelKey = key
    tab.btn:SetScript("OnClick", function()
      onClick()
    end)
    panelTabs[#panelTabs + 1] = tab
    relayout()
    paint()
    applyShown()
    return {
      setBadge = function(count)
        tab.unread = tonumber(count) or 0
        paint()
      end,
    }
  end
  -- Hides or shows an addon panel's tab; the tabs after it close the gap.
  -- An unknown key changes nothing.
  toggle.setPanelTabShown = function(key, shown)
    for _, tab in ipairs(panelTabs) do
      if tab.panelKey == key then
        tab.hidden = shown == false
        if tab.hidden then
          tab.btn:Hide()
        end
        relayout()
        paint()
        applyShown()
        return
      end
    end
  end
  toggle.setSelectedPanel = function(key)
    selectedPanel = key
    paint()
    anchorIfActiveChanged()
  end
  toggle.getSelectedPanel = function()
    return selectedPanel
  end
  -- fn(mode) runs on a mode-tab click while a panel is selected.
  toggle.setModeClickHandler = function(fn)
    modeClickHandler = fn
  end
  -- fn() runs on a click of the current mode's tab when no panel was selected.
  toggle.setCurrentModeClickHandler = function(fn)
    currentModeClickHandler = fn
  end
  return paint
end

ns.ContactsListTabLayout = TabLayout
return TabLayout
