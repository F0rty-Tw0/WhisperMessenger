local WindowGrowAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")
local AnimAlloc = require("tests.helpers.anim_alloc")

local ALLOC_BUDGET_KB = 1
local TICKS = 1000

local function rect(frame, left, bottom, right, top)
  rawset(frame, "GetLeft", function()
    return left
  end)
  rawset(frame, "GetBottom", function()
    return bottom
  end)
  rawset(frame, "GetRight", function()
    return right
  end)
  rawset(frame, "GetTop", function()
    return top
  end)
end

-- The window, button and panel, with every per-tick frame call counted and
-- allocation-free (see tests/helpers/anim_alloc.lua).
local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  local icon = factory.CreateFrame("Button", "Fab", parent)
  rect(frame, 100, 100, 460, 740)
  rect(icon, 80, 720, 122, 762)
  frame:SetAlpha(0.8)
  local counts = {}
  local animation = WindowGrowAnimation.Attach(frame, {
    factory = factory,
    parent = parent,
    theme = Theme,
    setAlphaHeld = function() end,
    refreshAlpha = function() end,
  })
  AnimAlloc.Quiet(animation.ghost, counts)
  AnimAlloc.Quiet(frame, counts)
  return animation, icon, counts
end

return function()
  -- test_open_animation_tick_allocates_nothing
  do
    local animation, icon, counts = build()
    local step = animation.beginOpen(icon)
    step(0.3, 0.6)
    AnimAlloc.Reset(counts)
    local kb = AnimAlloc.Measure(function()
      step(0.3, 0.6)
    end, TICKS)
    assert(kb < ALLOC_BUDGET_KB, "expected no per-tick garbage, got " .. kb .. " KB over " .. TICKS .. " ticks")
    assert(counts.SetPoint == TICKS and counts.ClearAllPoints == TICKS and counts.SetSize == TICKS, "the panel is still placed once per tick")
    assert(counts.SetAlpha == 2 * TICKS, "the panel and the window each fade once per tick")
  end

  -- test_close_animation_tick_allocates_nothing
  do
    local animation, icon, counts = build()
    local step = animation.beginClose(icon)
    step(0.3, 0.6)
    AnimAlloc.Reset(counts)
    local kb = AnimAlloc.Measure(function()
      step(0.3, 0.6)
    end, TICKS)
    assert(kb < ALLOC_BUDGET_KB, "expected no per-tick garbage, got " .. kb .. " KB over " .. TICKS .. " ticks")
    assert(counts.SetPoint == TICKS and counts.ClearAllPoints == TICKS and counts.SetSize == TICKS, "the panel is still placed once per tick")
    assert(counts.SetAlpha == TICKS, "only the panel fades while closing")
  end
end
