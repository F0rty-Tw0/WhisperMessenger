local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Shared by the modern and Native WoW HUD footer tabs: which modes are
-- visible, and anchoring the visible tab buttons as equal segments.
local TabLayout = {}

TabLayout.MODES = { "whispers", "groups", "requests" }

local DEFAULT_MODES = { "whispers", "groups" }

-- tabs: { whispers = tab, groups = tab, requests = tab }, each with `.btn`.
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

-- Three tabs wrap to two rows when any tab's natural width (label plus an
-- always-reserved badge, so unread counts never flip it) exceeds a third of
-- the strip. A width of 0 means "not laid out yet": keep one row.
function TabLayout.NeedsWrap(visible, width, naturalWidth)
  if #visible < 3 or not width or width <= 0 then
    return false
  end
  local third = math.floor(width / 3)
  for _, tab in ipairs(visible) do
    if naturalWidth(tab) > third then
      return true
    end
  end
  return false
end

-- Wrapped: the first two tabs share the top row (half each), the third
-- spans the bottom row. rowHeight is the height of one row.
local function anchorWrapped(frame, visible, top, rowHeight)
  local first, middle, last = visible[1], visible[2], visible[3]
  first.btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, top)
  first.btn:SetPoint("BOTTOMRIGHT", frame, "TOP", 0, -rowHeight)
  middle.btn:SetPoint("TOPLEFT", frame, "TOP", 0, top)
  middle.btn:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -rowHeight)
  last.btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -rowHeight)
  last.btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
end

-- Two tabs split the strip at its centre with anchors alone. Three tabs
-- anchor the outer ones to a third of the width (re-run on resize) and
-- stretch the middle one between them; with rowHeight they wrap to two rows
-- instead. Two-point anchors define every width, so a template's own
-- resize-on-show can't change it.
function TabLayout.Anchor(frame, visible, topInset, rowHeight)
  local top = -(topInset or 0)
  for _, tab in ipairs(visible) do
    tab.btn:ClearAllPoints()
  end
  local first, last = visible[1], visible[#visible]
  if first == nil then
    return
  end
  if #visible == 1 then
    first.btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, top)
    first.btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    return
  end
  if #visible == 2 then
    first.btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, top)
    first.btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 0, 0)
    last.btn:SetPoint("TOPLEFT", frame, "TOP", 0, top)
    last.btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    return
  end
  if rowHeight then
    anchorWrapped(frame, visible, top, rowHeight)
    return
  end
  local third = math.floor((frame:GetWidth() or 0) / 3)
  first.btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, top)
  first.btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", third, 0)
  last.btn:SetPoint("TOPLEFT", frame, "TOPRIGHT", -third, top)
  last.btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local middle = visible[2]
  middle.btn:SetPoint("TOPLEFT", first.btn, "TOPRIGHT", 0, 0)
  middle.btn:SetPoint("BOTTOMRIGHT", last.btn, "BOTTOMLEFT", 0, 0)
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

-- Mode, wrap and unread controller shared by both footers. Sets
-- reservedHeightFor, setMode, getMode, setModes, setShown, setUnreadCounts
-- and setLanguage on toggle, binds each tab's OnClick, and returns the paint
-- function (for hover handlers).
--
-- tabsByMode: { whispers = tab, groups = tab, requests = tab }; each tab has
-- `.btn`, `.mode` and a writable `.unread`.
-- opts:
--   initialMode, onModeChanged(mode)
--   tabHeight          : height of one row
--   topInset           : TabLayout.Anchor top inset
--   naturalWidth(tab)  : one-row width a tab needs (see NeedsWrap)
--   paint(mode, visible)
--   relabel(tab)       : re-reads the tab's label from the active locale
--   afterAnchor(wrapped, visible) : optional, runs after every re-anchor
function TabLayout.BindController(toggle, frame, tabsByMode, opts)
  local onModeChanged = opts.onModeChanged or function(_mode) end
  local currentMode = opts.initialMode or "whispers"
  local tabHeight = opts.tabHeight
  local visibleModes = nil
  local visible = {}

  local function paint()
    opts.paint(currentMode, visible)
  end

  -- Footer height at a pane width: two rows when the three tabs wrap.
  local function reservedHeightFor(width)
    return TabLayout.NeedsWrap(visible, width, opts.naturalWidth) and 2 * tabHeight or tabHeight
  end

  -- Wraps or unwraps for the current width; no allocation (runs on resize).
  local function anchorTabs()
    local height = reservedHeightFor(frame:GetWidth())
    local wrapped = height > tabHeight
    frame:SetHeight(height)
    TabLayout.Anchor(frame, visible, opts.topInset, wrapped and tabHeight or nil)
    if opts.afterAnchor then
      opts.afterAnchor(wrapped, visible)
    end
  end

  local function setMode(mode)
    currentMode = TabLayout.ResolveMode(mode, visible)
    paint()
  end

  local function relayout()
    visible = TabLayout.VisibleTabs(tabsByMode, visibleModes)
    anchorTabs()
  end

  relayout()
  -- Three tabs anchor to thirds of the width (or wrap); re-anchor while
  -- the contacts pane is resized.
  frame:SetScript("OnSizeChanged", function()
    if #visible == 3 then
      anchorTabs()
    end
  end)
  for _, mode in ipairs(TabLayout.MODES) do
    tabsByMode[mode].btn:SetScript("OnClick", function()
      if currentMode ~= mode then
        setMode(mode)
        onModeChanged(mode)
      end
    end)
  end
  paint()

  toggle.reservedHeightFor = reservedHeightFor
  toggle.setMode = setMode
  toggle.getMode = function()
    return currentMode
  end
  -- modes: visible tabs, e.g. { "whispers", "groups", "requests" }.
  toggle.setModes = function(modes)
    visibleModes = modes
    relayout()
    setMode(currentMode)
  end
  toggle.setShown = function(shown)
    frame:SetShown(shown)
  end
  toggle.setUnreadCounts = function(whispersCount, groupsCount, requestsCount)
    tabsByMode.whispers.unread = tonumber(whispersCount) or 0
    tabsByMode.groups.unread = tonumber(groupsCount) or 0
    tabsByMode.requests.unread = tonumber(requestsCount) or 0
    paint()
  end
  toggle.setLanguage = function()
    for _, mode in ipairs(TabLayout.MODES) do
      opts.relabel(tabsByMode[mode])
    end
    -- Label widths changed: re-check the wrap.
    anchorTabs()
    paint()
  end
  return paint
end

ns.ContactsListTabLayout = TabLayout
return TabLayout
