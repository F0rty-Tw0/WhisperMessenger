local CompactWindow = require("tests.helpers.compact_window")

local build, lay, panelOf = CompactWindow.Build, CompactWindow.Lay, CompactWindow.Panel
local runClock, hasClock, fire = CompactWindow.RunClock, CompactWindow.HasClock, CompactWindow.Fire

local function none()
  return nil
end

return function()
  -- test_a_minimap_source_opens_on_the_panels_own_clock
  do
    local case
    case = build({
      getDockIcon = none,
      getGrowSource = function()
        return case.minimap
      end,
    })
    lay(case)
    local frame = case.window.frame
    frame:Show()
    local panel = panelOf(case)
    assert(panel:IsShown() and hasClock(panel), "the panel runs its own clock")
    local _, _, _, x, y = panel:GetPoint()
    assert(x == 1516 and y == 116, "grows from the minimap icon's centre, got " .. tostring(x) .. "," .. tostring(y))
    assert(frame:GetAlpha() == 0, "the window waits unseen under the panel")
    runClock(panel)
    assert(frame:GetAlpha() == 1 and not panel:IsShown(), "done: full alpha, panel gone")
  end

  -- test_reopening_during_a_minimap_shrink_stops_it_and_ends_at_full_alpha  (Review Focus 1)
  do
    local case
    case = build({
      getDockIcon = none,
      getGrowSource = function()
        return case.minimap
      end,
    })
    lay(case)
    local frame = case.window.frame
    frame:Show()
    local panel = panelOf(case)
    runClock(panel)
    frame:Hide()
    assert(panel:IsShown() and hasClock(panel), "shrinking into the minimap icon")
    panel.scripts.OnUpdate(panel, 0.05)
    frame:Show()
    assert(frame:GetAlpha() == 0, "the new grow took over from the shrink")
    runClock(panel)
    assert(frame:GetAlpha() == 1, "full alpha, got " .. tostring(frame:GetAlpha()))
    assert(not panel:IsShown() and not hasClock(panel), "no second panel clock left running")
  end

  -- test_switching_off_mid_grow_releases_the_alpha_hold  (Review Focus 2)
  do
    local on = true
    local case = build({
      isGrowAnimationOn = function()
        return on
      end,
    })
    local frame = case.window.frame
    frame:Show()
    assert(case.step ~= nil and case.instant ~= true, "button-driven grow")
    case.step(0.8, 0.95)
    assert(frame:GetAlpha() < 1, "mid-fade")
    on = false
    frame:Hide()
    assert(case.homes == 1 and case.homeInstant == true and case.step == nil, "the button jumps home, no step to finish")
    assert(frame:GetAlpha() == 1, "the instant ride never sends (1, 1), so finish() must release the hold, got " .. tostring(frame:GetAlpha()))
  end

  -- test_a_hidden_button_jumps_on_and_the_window_grows_from_the_minimap  (Review Focus 5)
  do
    local case
    case = build({
      getGrowSource = function()
        return case.minimap
      end,
    })
    lay(case)
    case.fab:Hide()
    local frame = case.window.frame
    frame:Show()
    assert(case.rides == 1 and case.instant == true and case.step == nil, "the button jumps onto the spot")
    local panel = panelOf(case)
    local _, _, _, x, y = panel:GetPoint()
    assert(panel:IsShown() and x == 1516 and y == 116, "the window grows from the minimap icon")
    runClock(panel)
    assert(frame:GetAlpha() == 1, "grown")
    frame:Hide()
    assert(case.homes == 1 and case.homeInstant == true and case.step == nil, "the button jumps home")
    assert(panel:IsShown() and hasClock(panel), "and the window shrinks into the minimap icon")
    runClock(panel)
    assert(not panel:IsShown(), "gone")
  end

  -- test_the_button_source_runs_both_ways_on_the_buttons_clock
  do
    local case = build()
    lay(case)
    local frame = case.window.frame
    frame:Show()
    local panel = panelOf(case)
    assert(case.step ~= nil and case.instant ~= true, "the button's glide drives the grow")
    assert(not hasClock(panel), "the panel has no clock of its own")
    case.step(1, 1)
    frame:Hide()
    assert(case.homes == 1 and case.step ~= nil and case.homeInstant ~= true, "and the shrink")
    assert(not hasClock(panel), "still no panel clock")
  end

  -- test_switch_off_opens_and_closes_instantly_and_the_button_jumps
  do
    local case = build({
      isGrowAnimationOn = function()
        return false
      end,
    })
    lay(case)
    local frame = case.window.frame
    frame:Show()
    local panel = panelOf(case)
    assert(case.instant == true and case.step == nil, "the button jumps on")
    assert(frame:GetAlpha() == 1 and not panel:IsShown() and not hasClock(panel), "no animation runs")
    frame:Hide()
    assert(case.homeInstant == true and case.step == nil, "the button jumps home")
    assert(not panel:IsShown() and not hasClock(panel), "no shrink either")
  end

  -- test_no_source_and_no_button_opens_at_full_alpha
  do
    local case = build({ getDockIcon = none, getGrowSource = none })
    lay(case)
    local frame = case.window.frame
    frame:Show()
    local panel = panelOf(case)
    assert(frame:GetAlpha() == 1 and not panel:IsShown(), "nothing to grow from")
    frame:Hide()
    assert(not panel:IsShown() and case.homes == 0, "and nothing to shrink into")
  end

  -- test_alt_z_return_with_a_minimap_source_does_not_replay
  do
    local case
    case = build({
      getDockIcon = none,
      getGrowSource = function()
        return case.minimap
      end,
    })
    lay(case)
    local frame = case.window.frame
    frame:Show()
    local panel = panelOf(case)
    runClock(panel)
    fire(frame, "OnHide")
    assert(not panel:IsShown() and not hasClock(panel), "Alt+Z hid the parent, not the window: no shrink")
    CompactWindow.ParentShows(frame)
    assert(frame:GetAlpha() == 1 and not panel:IsShown() and not hasClock(panel), "and no replay")
  end

  -- test_close_shrinks_into_the_source_it_grew_from
  do
    local calls = 0
    local case
    case = build({
      getDockIcon = none,
      getGrowSource = function()
        calls = calls + 1
        return calls == 1 and case.minimap or case.fab
      end,
    })
    lay(case)
    local frame = case.window.frame
    frame:Show()
    runClock(panelOf(case))
    frame:Hide()
    assert(calls == 1, "the remembered source is still visible: no re-resolve, got " .. calls)
    assert(panelOf(case):IsShown(), "shrinking")
  end

  -- test_close_re_resolves_when_the_source_is_gone
  do
    local calls = 0
    local case
    case = build({
      getDockIcon = none,
      getGrowSource = function()
        calls = calls + 1
        return calls == 1 and case.minimap or nil
      end,
    })
    lay(case)
    local frame = case.window.frame
    frame:Show()
    local panel = panelOf(case)
    runClock(panel)
    case.minimap:Hide()
    frame:Hide()
    assert(calls == 2, "asked again, got " .. calls)
    assert(not panel:IsShown() and not hasClock(panel), "none left: it closes instantly")
  end

  -- test_a_window_built_without_grow_options_has_no_source
  do
    local case = build({ getGrowSource = false })
    local frame = case.window.frame
    frame:Show()
    assert(case.instant == true and case.step == nil, "the button jumps on")
    assert(frame:GetAlpha() == 1, "and the window is never held unseen")
  end

  -- test_hiding_a_window_that_never_opened_changes_nothing  (guard)
  do
    local case
    case = build({
      getDockIcon = none,
      getGrowSource = function()
        return case.minimap
      end,
    })
    lay(case)
    case.window.frame:Hide()
    assert(not panelOf(case):IsShown() and case.homes == 0, "no phantom shrink")
  end
end
