local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Places the tabs of a strip: all of them while they fit, else whole tabs from
-- a `first` index with two arrows pinned to the strip's right end. Skin-free:
-- the skin sizes its tabs, supplies the arrow buttons, then calls layout().
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

-- Shows and chains tabs `from`..`to` from the strip's left edge, hides the rest.
local function chain(frame, visible, from, to, spacing)
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
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
      end
      previous = btn
    end
  end
end

local function fitsStrip(ctx)
  local width = ctx.frame:GetWidth()
  if width <= 0 then
    return true
  end
  local visible = ctx.visible

  return runWidth(visible, 1, #visible, ctx.opts.spacing) <= width - ctx.opts.endReserve
end

-- Room left of the back arrow.
local function availableWidth(ctx)
  local opts = ctx.opts

  return ctx.frame:GetWidth() - ARROW_COUNT * opts.arrowWidth - opts.endReserve - opts.spacing
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
  chain(ctx.frame, visible, 1, #visible, ctx.opts.spacing)
  ctx.arrows.prev:Hide()
  ctx.arrows.next:Hide()
  ctx.frame:EnableMouseWheel(false)
end

local function placeOverflowing(ctx)
  local visible = ctx.visible
  local last = lastFitting(visible, ctx.first, availableWidth(ctx), ctx.opts.spacing)
  chain(ctx.frame, visible, ctx.first, last, ctx.opts.spacing)
  setArrowEnabled(ctx, ctx.arrows.prev, ctx.first > 1)
  setArrowEnabled(ctx, ctx.arrows.next, last < #visible)
  ctx.arrows.prev:Show()
  ctx.arrows.next:Show()
  ctx.frame:EnableMouseWheel(true)
end

local function place(ctx)
  if fitsStrip(ctx) then
    placeFitting(ctx)
    return
  end
  placeOverflowing(ctx)
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
  arrows.prev:SetPoint("RIGHT", arrows.next, "LEFT", 0, 0)
  arrows.prev:Hide()
  arrows.next:Hide()

  local ctx = { frame = frame, opts = opts, arrows = arrows, enabled = {}, first = 1 }
  local scroller = {}

  -- visible: array of { btn = Button } in display order.
  function scroller.layout(visible, activeTab)
    ctx.visible = visible
    ctx.activeTab = activeTab
    place(ctx)
  end

  function scroller.refresh()
    if ctx.visible then
      scroller.layout(ctx.visible, ctx.activeTab)
    end
  end

  function scroller.paintArrows()
    paintArrows(ctx)
  end

  frame:SetScript("OnSizeChanged", function()
    scroller.refresh()
  end)

  return scroller
end

ns.ContactsListTabScroller = TabScroller
return TabScroller
