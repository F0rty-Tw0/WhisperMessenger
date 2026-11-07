local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Fit = ns.ContactsListTabScrollerFit or require("WhisperMessenger.UI.ContactsList.TabScrollerFit")

-- Places the tabs of a strip: all of them while they fit, else whole tabs from
-- a `first` index between two arrows: back at the window's left edge, forward
-- at its right edge. Tabs may draw up to 8 px narrower ("tight") when that
-- shows more of them. Skin-free: the skin sizes its tabs, supplies the arrow
-- buttons and the squeeze hook, then calls layout().
local TabScroller = {}

-- Place passes one request may take: the first plus the re-runs for requests
-- that arrived while it ran. Stops a width read that fires OnSizeChanged on
-- every pass from looping.
local MAX_PASSES = 4

-- Stands in for a skin without a squeeze hook: tabs keep their live width.
local function noSqueeze(_tab, _px) end

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
  while Fit.lastFitting(ctx.tight, visible, ctx.first, available, ctx.opts.spacing) < target do
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
    Fit.squeezeTight(ctx, 1, count)
  end
  chain(ctx.frame, ctx.visible, 1, count, ctx.opts.spacing, 0)
  ctx.arrows.prev:Hide()
  ctx.arrows.next:Hide()
  ctx.frame:EnableMouseWheel(false)
end

local function placeOverflowing(ctx, reveal)
  local visible = ctx.visible
  local available = Fit.availableWidth(ctx)
  local spacing = ctx.opts.spacing
  ctx.first = math.max(1, math.min(ctx.first, Fit.maxFirstIndex(ctx.tight, visible, available, spacing)))
  if reveal then
    revealActive(ctx, available)
  end
  local last = Fit.lastFitting(ctx.tight, visible, ctx.first, available, spacing)
  Fit.drawRun(ctx, ctx.first, last, available)
  chain(ctx.frame, visible, ctx.first, last, spacing, ctx.opts.arrowWidth + spacing - ctx.outset)
  setArrowEnabled(ctx, ctx.arrows.prev, ctx.first > 1)
  setArrowEnabled(ctx, ctx.arrows.next, last < #visible)
  ctx.arrows.prev:Show()
  ctx.arrows.next:Show()
  ctx.frame:EnableMouseWheel(true)
end

-- Hides the tabs an earlier pass placed that the new list dropped: a pass over
-- a stale list can show a tab the skin has since hidden, and chain() only
-- walks the new list.
local function hideDropped(previous, requested)
  if not previous or previous == requested then
    return
  end
  for _, tab in ipairs(previous) do
    if not indexOf(requested, tab) then
      tab.btn:Hide()
    end
  end
end

-- One pass over the newest requested list. `reveal` scrolls the active tab
-- into view; a manual scroll skips it.
local function placeOnce(ctx, reveal)
  hideDropped(ctx.visible, ctx.requested)
  ctx.visible = ctx.requested
  ctx.activeTab = ctx.requestedActive
  Fit.measure(ctx)
  local kind = Fit.fitKind(ctx)
  ctx.fits = kind ~= "overflow"
  if ctx.fits then
    placeFitting(ctx, kind)
    return
  end
  placeOverflowing(ctx, reveal)
end

local function placeUntilSettled(ctx, reveal)
  for _ = 1, MAX_PASSES do
    ctx.again = false
    placeOnce(ctx, reveal)
    if not ctx.again then
      return
    end
    reveal = ctx.againReveal
  end
end

-- A width read inside a pass can fire the strip's OnSizeChanged synchronously
-- (the client does), which lands back here. A nested pass would overwrite the
-- widths the outer one is measuring, so it only marks `again`, and the outer
-- pass runs once more with the newest list after it finishes.
local function place(ctx, reveal)
  if ctx.placing then
    ctx.again = true
    ctx.againReveal = reveal
    return
  end
  ctx.placing = true
  local ok, err = xpcall(function()
    placeUntilSettled(ctx, reveal)
  end, debug.traceback)
  ctx.placing = false
  if not ok then
    error(err, 0)
  end
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
    ctx.requested = visible
    ctx.requestedActive = activeTab
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
    if ctx.requested then
      scroller.layout(ctx.requested, ctx.requestedActive)
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
