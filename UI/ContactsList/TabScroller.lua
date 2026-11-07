local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Places the tabs of a strip: all of them while they fit, else whole tabs from
-- a `first` index between two arrows: back at the strip's left end, forward at
-- its right end. Skin-free: the skin sizes its tabs, supplies the arrow
-- buttons, then calls layout().
local TabScroller = {}

-- Back and forward arrow.
local ARROW_COUNT = 2

local function tabWidth(tab)
  return tab.btn:GetWidth()
end

-- Width of tabs `from`..`to` with the spacing between them.
local function runWidth(visible, from, to, spacing)
  if to < from then
    return 0
  end
  local total = (to - from) * spacing
  for index = from, to do
    total = total + tabWidth(visible[index])
  end

  return total
end

-- Last index whose whole tab fits in `available` when the run starts at
-- `first`; the tab at `first` counts even when it is wider than `available`.
local function lastFitting(visible, first, available, spacing)
  local last = first
  local used = tabWidth(visible[first])
  while last < #visible do
    local usedWithNext = used + spacing + tabWidth(visible[last + 1])
    if usedWithNext > available then
      break
    end
    used = usedWithNext
    last = last + 1
  end

  return last
end

-- Smallest first-index whose run to the last tab fits in `available`; the last
-- tab itself when none does. Scrolling further would leave a gap at the end.
local function maxFirstIndex(visible, available, spacing)
  for index = 1, #visible do
    if runWidth(visible, index, #visible, spacing) <= available then
      return index
    end
  end

  return #visible
end

local function indexOf(visible, tab)
  for index, candidate in ipairs(visible) do
    if candidate == tab then
      return index
    end
  end

  return nil
end

-- Moves `first` the least that brings the active tab into view.
local function revealActive(ctx, available)
  local visible = ctx.visible
  local target = ctx.activeTab and indexOf(visible, ctx.activeTab)
  if not target then
    return
  end
  if target < ctx.first then
    ctx.first = target
    return
  end
  while lastFitting(visible, ctx.first, available, ctx.opts.spacing) < target do
    ctx.first = ctx.first + 1
  end
end

-- Shows and chains tabs `from`..`to` starting `left` px from the strip's left
-- edge, hides the rest.
local function chain(frame, visible, from, to, spacing, left)
  local previous = nil
  for index, tab in ipairs(visible) do
    local btn = tab.btn
    if index < from or index > to then
      btn:Hide()
    else
      btn:Show()
      btn:ClearAllPoints()
      if previous then
        btn:SetPoint("TOPLEFT", previous, "TOPRIGHT", spacing, 0)
      else
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", left, 0)
      end
      previous = btn
    end
  end
end

local function fitsStrip(ctx)
  local width = ctx.frame:GetWidth() or 0
  local visible = ctx.visible
  -- No tabs always fit, even on a strip narrower than the end reserve.
  if width <= 0 or #visible == 0 then
    return true
  end

  return runWidth(visible, 1, #visible, ctx.opts.spacing) <= width - ctx.opts.endReserve
end

-- Room between the arrows.
local function availableWidth(ctx)
  local opts = ctx.opts

  return ctx.frame:GetWidth() - ARROW_COUNT * opts.arrowWidth - opts.endReserve - 2 * opts.spacing
end

local function setArrowEnabled(ctx, btn, enabled)
  ctx.enabled[btn] = enabled
  btn:SetEnabled(enabled)
  if ctx.opts.paintArrow then
    ctx.opts.paintArrow(btn, enabled)
  end
end

local function paintArrows(ctx)
  if not ctx.opts.paintArrow then
    return
  end
  ctx.opts.paintArrow(ctx.arrows.prev, ctx.enabled[ctx.arrows.prev])
  ctx.opts.paintArrow(ctx.arrows.next, ctx.enabled[ctx.arrows.next])
end

local function placeFitting(ctx)
  local visible = ctx.visible
  ctx.first = 1
  chain(ctx.frame, visible, 1, #visible, ctx.opts.spacing, 0)
  ctx.arrows.prev:Hide()
  ctx.arrows.next:Hide()
  ctx.frame:EnableMouseWheel(false)
end

local function placeOverflowing(ctx, reveal)
  local visible = ctx.visible
  local available = availableWidth(ctx)
  local spacing = ctx.opts.spacing
  ctx.first = math.max(1, math.min(ctx.first, maxFirstIndex(visible, available, spacing)))
  if reveal then
    revealActive(ctx, available)
  end
  local last = lastFitting(visible, ctx.first, available, spacing)
  chain(ctx.frame, visible, ctx.first, last, spacing, ctx.opts.arrowWidth + spacing)
  setArrowEnabled(ctx, ctx.arrows.prev, ctx.first > 1)
  setArrowEnabled(ctx, ctx.arrows.next, last < #visible)
  ctx.arrows.prev:Show()
  ctx.arrows.next:Show()
  ctx.frame:EnableMouseWheel(true)
end

-- `reveal` scrolls the active tab into view; a manual scroll skips it.
local function place(ctx, reveal)
  ctx.fits = fitsStrip(ctx)
  if ctx.fits then
    placeFitting(ctx)
    return
  end
  placeOverflowing(ctx, reveal)
end

-- opts: spacing (gap between tabs), endReserve (pixels kept free right of the
-- last tab), arrowWidth, createArrows(parent) -> { prev, next } buttons,
-- paintArrow(btn, enabled) (optional skin repaint).
function TabScroller.Attach(factory, frame, opts)
  -- The holder keeps the arrows out of the strip's own Button children.
  local holder = factory.CreateFrame("Frame", nil, frame)
  holder:SetAllPoints(frame)
  local arrows = opts.createArrows(holder)
  arrows.next:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  arrows.prev:SetPoint("LEFT", frame, "LEFT", 0, 0)
  arrows.prev:Hide()
  arrows.next:Hide()

  -- Arrows start disabled, so a repaint before the first overflow is defined.
  local enabled = { [arrows.prev] = false, [arrows.next] = false }
  local ctx = { frame = frame, opts = opts, arrows = arrows, enabled = enabled, first = 1 }
  local scroller = {}

  -- visible: array of { btn = Button } in display order.
  function scroller.layout(visible, activeTab)
    ctx.visible = visible
    ctx.activeTab = activeTab
    place(ctx, true)
  end

  -- One tab per step (+1 forward, -1 back); the active tab is not revealed.
  function scroller.scroll(step)
    if not ctx.visible or ctx.fits then
      return
    end
    ctx.first = ctx.first + step
    place(ctx, false)
  end

  function scroller.refresh()
    if ctx.visible then
      scroller.layout(ctx.visible, ctx.activeTab)
    end
  end

  function scroller.paintArrows()
    paintArrows(ctx)
  end

  arrows.prev:SetScript("OnClick", function()
    scroller.scroll(-1)
  end)
  arrows.next:SetScript("OnClick", function()
    scroller.scroll(1)
  end)
  frame:SetScript("OnMouseWheel", function(_self, delta)
    scroller.scroll(delta > 0 and -1 or 1)
  end)
  frame:SetScript("OnSizeChanged", function()
    scroller.refresh()
  end)

  return scroller
end

ns.ContactsListTabScroller = TabScroller
return TabScroller
