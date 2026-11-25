local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")

-- The D-pad on a settings page: UP / DOWN go row by row in on-screen order,
-- LEFT / RIGHT stay in the row, and LEFT from its leftmost control goes to
-- the open page's tab in the page list. The game's own search only looks in
-- a 45-degree cone, so it never finds a wide drop-down under a slider's
-- − / + and picks controls of other rows. A jump does not scroll, so a
-- target out of view is scrolled to the middle, as the game does for its
-- own moves.
local GamepadSettingsRows = {}

local DIRECTIONS = { "UP", "DOWN", "LEFT", "RIGHT" }

-- Every visible D-pad stop under frame, with its screen rect.
local function collectStops(nav, frame, stops)
  if not frame:IsShown() or type(frame._wmPadStep) == "function" then
    return
  end
  if nav.isStop(frame) then
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if left and right and top and bottom then
      stops[#stops + 1] = { frame = frame, left = left, right = right, middle = (top + bottom) / 2, height = top - bottom }
    end
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    collectStops(nav, child, stops)
  end
end

-- Rows from the top of the screen down, each row from left to right. A stop
-- joins the row whose first stop it shares its middle with, give or take
-- half the smaller height.
local function groupRows(stops)
  table.sort(stops, function(a, b)
    return a.middle > b.middle
  end)
  local rows = {}
  for _, stop in ipairs(stops) do
    local row = rows[#rows]
    local first = row and row[1]
    if first and first.middle - stop.middle < math.min(first.height, stop.height) / 2 then
      row[#row + 1] = stop
    else
      rows[#rows + 1] = { stop }
    end
  end
  for _, row in ipairs(rows) do
    table.sort(row, function(a, b)
      return a.left < b.left
    end)
  end
  return rows
end

-- The stop of `row` with the smallest sideways gap to `from`, the leftmost
-- of equals; nil without a row.
local function nearestInRow(row, from)
  local best, bestGap
  for _, stop in ipairs(row or {}) do
    local gap = math.max(0, stop.left - from.right, from.left - stop.right)
    if best == nil or gap < bestGap then
      best, bestGap = stop, gap
    end
  end
  return best and best.frame
end

local function scrollIntoView(scrollView, target)
  local view = scrollView and scrollView.scrollFrame
  if not view or not target:IsVisible() then
    return
  end
  local viewTop, viewBottom = view:GetTop(), view:GetBottom()
  local top, bottom = target:GetTop(), target:GetBottom()
  if not (viewTop and viewBottom and top and bottom) then
    return
  end
  if top <= viewTop and bottom >= viewBottom then
    return
  end
  local distance = (viewTop + viewBottom) / 2 - (top + bottom) / 2
  ScrollView.SetVerticalScroll(scrollView, ScrollView.GetOffset(scrollView) + distance)
end

-- options: scrollView (the pages' scroll view), menuScrollView (the page
-- list's), activeTab() -> the open page's tab or nil, panels (the pages;
-- false = not built yet), isEnabled() (false = no chain, all spatial).
-- Returns refresh: re-reads the screen and chains the visible page again.
function GamepadSettingsRows.New(nav, options)
  -- Frames with a target from the last refresh.
  local chained = {}

  local function activeTab()
    return options.activeTab and options.activeTab()
  end

  local function onJump(target)
    local scrollView = target == activeTab() and options.menuScrollView or options.scrollView
    scrollIntoView(scrollView, target)
  end

  -- The last row and a row's right end stay put: past them the game would
  -- pick a button of the page list or of another row. UP from the first row
  -- is the game's: the title bar.
  local function targetsOf(rows, rowIndex, column, tab)
    local row = rows[rowIndex]
    local stop = row[column]
    local left, right = row[column - 1], row[column + 1]
    return {
      UP = nearestInRow(rows[rowIndex - 1], stop),
      DOWN = nearestInRow(rows[rowIndex + 1], stop) or stop.frame,
      LEFT = left and left.frame or tab,
      RIGHT = (right or stop).frame,
    }
  end

  local function visibleStops()
    local stops = {}
    if not options.isEnabled() then
      return stops
    end
    for _, page in ipairs(options.panels or {}) do
      if page and page:IsVisible() then
        collectStops(nav, page, stops)
      end
    end
    return stops
  end

  return function()
    local rows = groupRows(visibleStops())
    local tab = activeTab()
    local previous = chained
    chained = {}
    for rowIndex, row in ipairs(rows) do
      for column, stop in ipairs(row) do
        local targets = targetsOf(rows, rowIndex, column, tab)
        chained[stop.frame] = true
        for _, dirName in ipairs(DIRECTIONS) do
          nav.setJumpTarget(stop.frame, dirName, targets[dirName])
          nav.onJump(stop.frame, dirName, onJump)
        end
      end
    end
    for frame in pairs(previous) do
      if not chained[frame] then
        for _, dirName in ipairs(DIRECTIONS) do
          nav.setJumpTarget(frame, dirName, nil)
        end
      end
    end
  end
end

ns.MessengerWindowGamepadSettingsRows = GamepadSettingsRows

return GamepadSettingsRows
