local ClassicGrow = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ClassicGrow")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")
local Rig = require("tests.helpers.grow_rig")

local SECONDS = Theme.LAYOUT.PHONE_RIDE_SECONDS
local DONE = SECONDS + 0.1
local WIDTH = 360

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  Rig.rect(frame, 100, 100, 460, 740)
  frame:SetAlpha(0.8)
  local case = { frame = frame, held = {}, refreshes = 0, on = true }
  case.iconA = Rig.icon(80, 720, 122, 762)
  case.iconB = Rig.icon(900, 300, 942, 342)
  case.source = case.iconA
  ClassicGrow.Attach(frame, {
    factory = factory,
    parent = parent,
    theme = Theme,
    windowAlpha = {
      setHeld = function(held)
        case.held[#case.held + 1] = held
      end,
      refreshWindowAlpha = function()
        case.refreshes = case.refreshes + 1
      end,
    },
    getSource = function()
      return case.source
    end,
    isOn = function()
      return case.on
    end,
  })
  case.ghost = Rig.ghostOf(frame)
  return case
end

local function open(case)
  case.frame:Show()
  Rig.tick(case.ghost, DONE)
end

local function near(case, icon)
  local x, y = Rig.center(case.ghost)
  local cx, cy = icon:GetLeft() / 2 + icon:GetRight() / 2, icon:GetBottom() / 2 + icon:GetTop() / 2
  return math.abs(x - cx) < 10 and math.abs(y - cy) < 10
end

return function()
  -- test_opening_grows_the_panel_out_of_the_source
  do
    local case = build()
    case.frame:Show()
    assert(case.frame:GetAlpha() == 0 and case.held[1] == true, "the real window waits unseen")
    assert(case.ghost:IsShown() and case.ghost.width <= 1, "the panel shows at once, as a point")
    Rig.tick(case.ghost, SECONDS / 2)
    assert(case.ghost.width > 1 and case.ghost.width < WIDTH, "growing, got " .. tostring(case.ghost.width))
    Rig.tick(case.ghost, DONE)
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "panel gone, clock stopped")
    assert(case.frame:GetAlpha() == 0.8 and case.held[#case.held] == false, "alpha released")
  end

  -- test_closing_shrinks_the_panel_into_the_source
  do
    local case = build()
    open(case)
    case.frame:Hide()
    assert(case.ghost:IsShown() and case.ghost.width == WIDTH, "starts as the window")
    Rig.tick(case.ghost, SECONDS / 2)
    assert(case.ghost.width > 1 and case.ghost.width < WIDTH, "shrinking")
    Rig.tick(case.ghost, DONE)
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "gone at the icon")
  end

  -- test_a_hide_before_the_first_open_plays_no_shrink
  do
    local case = build()
    case.frame:Hide()
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "never opened: nothing to shrink")
  end

  -- test_alt_z_hide_and_show_neither_close_nor_replay
  do
    local case = build()
    open(case)
    Rig.parentHides(case.frame)
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "the window is still open: no shrink")
    case.frame:Show()
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "coming back replays nothing")
    assert(case.frame:GetAlpha() == 0.8, "and stays visible")
  end

  -- test_alt_z_mid_grow_keeps_the_animation_going
  do
    local case = build()
    case.frame:Show()
    Rig.tick(case.ghost, Rig.STEP * 2)
    local width = case.ghost.width
    Rig.parentHides(case.frame)
    assert(case.ghost:IsShown() and Rig.running(case.ghost), "the grow keeps its state")
    case.frame:Show()
    Rig.tick(case.ghost, Rig.STEP)
    assert(case.ghost.width > width, "same run continues, not restarted")
  end

  -- test_switch_off_opens_and_closes_at_once_with_no_clock
  do
    local case = build()
    case.on = false
    case.frame:Show()
    assert(case.frame:GetAlpha() == 0.8 and #case.held == 0, "never held")
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "no panel, no OnUpdate")
    case.frame:Hide()
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "closing is instant too")
  end

  -- test_no_source_opens_and_closes_at_once
  do
    local case = build()
    case.source = nil
    case.frame:Show()
    assert(case.frame:GetAlpha() == 0.8 and not Rig.running(case.ghost), "instant open")
    case.frame:Hide()
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "instant close")
  end

  -- test_missing_options_mean_no_source
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local frame = factory.CreateFrame("Frame", "Window", parent)
    frame:SetAlpha(0.8)
    ClassicGrow.Attach(frame, {
      factory = factory,
      parent = parent,
      theme = Theme,
      windowAlpha = { setHeld = function() end, refreshWindowAlpha = function() end },
    })
    frame:Show()
    frame:Hide()
    assert(frame:GetAlpha() == 0.8, "instant, nothing held")
  end

  -- test_a_missing_switch_option_means_on
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local frame = factory.CreateFrame("Frame", "Window", parent)
    Rig.rect(frame, 100, 100, 460, 740)
    local icon = Rig.icon(80, 720, 122, 762)
    ClassicGrow.Attach(frame, {
      factory = factory,
      parent = parent,
      theme = Theme,
      windowAlpha = { setHeld = function() end, refreshWindowAlpha = function() end },
      getSource = function()
        return icon
      end,
    })
    frame:Show()
    assert(Rig.running(Rig.ghostOf(frame)), "the window grows out of its icon")
  end

  -- test_source_gone_at_close_re_resolves_to_the_new_icon
  do
    local case = build()
    open(case)
    case.iconA:Hide()
    case.source = case.iconB
    case.frame:Hide()
    Rig.tick(case.ghost, 0.2)
    assert(near(case, case.iconB), "shrinks into the icon that is there now")
  end

  -- test_source_gone_and_none_left_closes_at_once
  do
    local case = build()
    open(case)
    case.iconA:Hide()
    case.source = nil
    case.frame:Hide()
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "nothing to shrink into")
  end

  -- test_close_runs_into_the_remembered_source_while_it_is_still_there
  do
    local case = build()
    open(case)
    case.source = case.iconB -- the resolver moved on, icon A is still shown
    case.frame:Hide()
    Rig.tick(case.ghost, 0.2)
    assert(near(case, case.iconA), "same icon it grew from")
  end

  -- test_reopening_during_a_shrink_ends_at_full_alpha  (Review Focus 1)
  do
    local case = build()
    open(case)
    case.frame:Hide()
    Rig.tick(case.ghost, Rig.STEP * 2)
    assert(case.ghost.width > 1 and case.ghost.width < WIDTH, "mid shrink")
    case.frame:Show()
    assert(case.ghost.width <= 1, "the shrink stopped; a fresh grow starts at the icon")
    Rig.tick(case.ghost, DONE)
    assert(case.frame:GetAlpha() == 0.8, "full alpha, got " .. tostring(case.frame:GetAlpha()))
    assert(not case.ghost:IsShown() and case.held[#case.held] == false, "nothing left held")
  end

  -- test_reopening_during_a_shrink_with_the_switch_off_ends_at_full_alpha  (Review Focus 1)
  do
    local case = build()
    open(case)
    case.frame:Hide()
    Rig.tick(case.ghost, Rig.STEP * 2)
    case.on = false
    case.frame:Show()
    assert(not case.ghost:IsShown() and not Rig.running(case.ghost), "the shrink stopped")
    assert(case.frame:GetAlpha() == 0.8, "visible at once")
  end

  -- test_opening_with_the_switch_off_forgets_the_old_source  (Review Focus 4)
  do
    local case = build()
    open(case)
    case.frame:Hide()
    Rig.tick(case.ghost, DONE) -- closed; icon A was remembered
    case.on = false
    case.frame:Show() -- instant: must drop icon A
    case.on = true
    case.source = case.iconB -- icon A is still shown, but not what resolves now
    case.frame:Hide()
    Rig.tick(case.ghost, 0.2)
    assert(near(case, case.iconB), "shrinks into what resolves now, not the stale icon")
  end
end
