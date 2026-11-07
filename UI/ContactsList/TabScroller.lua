local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Places the tabs of a strip: all of them while they fit, else whole tabs from
-- a `first` index between two arrows: back at the window's left edge, forward
-- at its right edge. Tabs may draw up to MAX_SQUEEZE px narrower ("tight")
-- when that shows more of them. Skin-free: the skin sizes its tabs, supplies
-- the arrow buttons and the squeeze hook, then calls layout().
local TabScroller = {}

-- Back and forward arrow.
local ARROW_COUNT = 2

-- Most px a skin is asked to take off a tab's natural width.
local MAX_SQUEEZE = 8

-- Stands in for a skin without a squeeze hook: tabs keep their live width.
local function noSqueeze(_tab, _px) end

-- Width of tabs `from`..`to` plus spacing; `widths` is ctx.natural or ctx.tight.
local function runWidth(widths, visible, from, to, spacing)
  if to < from then
    return 0
  end
  local total = (to - from) * spacing
  for index = from, to do
    total = total + widths[visible[index]]
  end

  return total
end

-- Last index whose whole tab fits in `available` when the run starts at
-- `first`; the tab at `first` counts even when it is wider than `available`.
local function lastFitting(widths, visible, first, available, spacing)
  local last = first
  local used = widths[visible[first]]
  while last < #visible do
    local usedWithNext = used + spacing + widths[visible[last + 1]]
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
local function maxFirstIndex(widths, visible, available, spacing)
  for index = 1, #visible do
    if runWidth(widths, visible, index, #visible, spacing) <= available then
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
  while lastFitting(ctx.tight, visible, ctx.first, available, ctx.opts.spacing) < target do
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

-- Records each visible tab's tight and natural width; leaves it drawn natural.
local function measure(ctx)
  for _, tab in ipairs(ctx.visible) do
    ctx.squeeze(tab, MAX_SQUEEZE)
    ctx.tight[tab] = tab.btn:GetWidth()
    ctx.squeeze(tab, 0)
    ctx.natural[tab] = tab.btn:GetWidth()
  end
end

-- "natural": every tab fits at natural width; "tight": every tab fits only
-- squeezed; "overflow": arrows needed.
local function fitKind(ctx)
  local width = ctx.frame:GetWidth() or 0
  local visible = ctx.visible
  -- No tabs always fit, even on a strip narrower than the end reserve.
  if width <= 0 or #visible == 0 then
    return "natural"
  end
  local room = width - ctx.opts.endReserve
  local spacing = ctx.opts.spacing
  if runWidth(ctx.natural, visible, 1, #visible, spacing) <= room then
    return "natural"
  end
  if runWidth(ctx.tight, visible, 1, #visible, spacing) <= room then
    return "tight"
  end

  return "overflow"
end

-- Room between the arrows; the back arrow hangs `outset` px past the strip's
-- left edge, which gives that much more room.
-- Invariant: overflow room < fit room, because outset < 2 * arrowWidth +
-- 2 * spacing (modern 8 < 36, Native 11 < 50), so an overflowing view never
-- holds every tab; fitKind catches that case first.
local function availableWidth(ctx)
  local opts = ctx.opts

  return ctx.frame:GetWidth() - ARROW_COUNT * opts.arrowWidth - opts.endReserve - 2 * opts.spacing + ctx.outset
end

-- Draws tabs `from`..`to` px narrower than natural (0 = natural).
local function squeezeRun(ctx, from, to, px)
  for index = from, to do
    ctx.squeeze(ctx.visible[index], px)
  end
end

-- A shown run is drawn natural when its natural width fits `room`, else tight.
local function drawRun(ctx, from, to, room)
  if runWidth(ctx.natural, ctx.visible, from, to, ctx.opts.spacing) > room then
    squeezeRun(ctx, from, to, MAX_SQUEEZE)
  end
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

local function placeFitting(ctx, kind)
  local count = #ctx.visible
  ctx.first = 1
  if kind == "tight" then
    squeezeRun(ctx, 1, count, MAX_SQUEEZE)
  end
  chain(ctx.frame, ctx.visible, 1, count, ctx.opts.spacing, 0)
  ctx.arrows.prev:Hide()
  ctx.arrows.next:Hide()
  ctx.frame:EnableMouseWheel(false)
end

local function placeOverflowing(ctx, reveal)
  local visible = ctx.visible
  local available = availableWidth(ctx)
  local spacing = ctx.opts.spacing
  ctx.first = math.max(1, math.min(ctx.first, maxFirstIndex(ctx.tight, visible, available, spacing)))
  if reveal then
    revealActive(ctx, available)
  end
  local last = lastFitting(ctx.tight, visible, ctx.first, available, spacing)
  drawRun(ctx, ctx.first, last, available)
  chain(ctx.frame, visible, ctx.first, last, spacing, ctx.opts.arrowWidth + spacing - ctx.outset)
  setArrowEnabled(ctx, ctx.arrows.prev, ctx.first > 1)
  setArrowEnabled(ctx, ctx.arrows.next, last < #visible)
  ctx.arrows.prev:Show()
  ctx.arrows.next:Show()
  ctx.frame:EnableMouseWheel(true)
end

-- `reveal` scrolls the active tab into view; a manual scroll skips it.
local function place(ctx, reveal)
  measure(ctx)
  local kind = fitKind(ctx)
  ctx.fits = kind ~= "overflow"
  if ctx.fits then
    placeFitting(ctx, kind)
    return
  end
  placeOverflowing(ctx, reveal)
end

-- opts: spacing (gap between tabs), endReserve (pixels kept free right of the
-- last tab), arrowWidth, createArrows(parent) -> { prev, next } buttons,
-- arrowOutset (optional px the strip's left edge sits in from the window's;
-- the back arrow hangs that far out), squeeze(tab, px) (optional: draw the tab
-- px narrower than natural, 0 restores natural, stopping at the skin's floor),
-- paintArrow(btn, enabled) (optional skin repaint).
function TabScroller.Attach(factory, frame, opts)
  -- The holder keeps the arrows out of the strip's own Button children.
  local holder = factory.CreateFrame("Frame", nil, frame)
  holder:SetAllPoints(frame)
  local arrows = opts.createArrows(holder)
  local outset = opts.arrowOutset or 0
  arrows.next:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  arrows.prev:SetPoint("LEFT", frame, "LEFT", -outset, 0)
  arrows.prev:Hide()
  arrows.next:Hide()

  -- Arrows start disabled, so a repaint before the first overflow is defined.
  local enabled = { [arrows.prev] = false, [arrows.next] = false }
  local ctx = {
    frame = frame,
    opts = opts,
    outset = outset,
    squeeze = opts.squeeze or noSqueeze,
    arrows = arrows,
    enabled = enabled,
    first = 1,
    natural = {},
    tight = {},
  }
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
