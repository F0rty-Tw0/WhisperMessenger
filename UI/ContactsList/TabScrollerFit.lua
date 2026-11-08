local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The width maths of TabScroller: measuring a strip's tabs, how a run fits,
-- and drawing a shown run natural or tight. Skin-free; ctx is the scroller's.
local TabScrollerFit = {}

-- Back and forward arrow.
local ARROW_COUNT = 2

-- Most px a skin is asked to take off a tab's natural width.
local MAX_SQUEEZE = 8

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

-- Draws tabs `from`..`to` at their tightest.
local function squeezeTight(ctx, from, to)
  squeezeRun(ctx, from, to, MAX_SQUEEZE)
end

TabScrollerFit.measure = measure
TabScrollerFit.fitKind = fitKind
TabScrollerFit.availableWidth = availableWidth
TabScrollerFit.lastFitting = lastFitting
TabScrollerFit.maxFirstIndex = maxFirstIndex
TabScrollerFit.drawRun = drawRun
TabScrollerFit.squeezeTight = squeezeTight

ns.ContactsListTabScrollerFit = TabScrollerFit
return TabScrollerFit
