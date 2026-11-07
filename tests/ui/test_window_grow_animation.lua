local WindowGrowAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

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

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  local icon = factory.CreateFrame("Button", "Fab", parent)
  rect(frame, 100, 100, 460, 740)
  rect(icon, 80, 720, 122, 762)
  frame:SetAlpha(0.8)
  local case = { frame = frame, icon = icon, factory = factory, parent = parent, held = {}, refreshes = 0 }
  case.animation = WindowGrowAnimation.Attach(frame, {
    factory = factory,
    parent = parent,
    theme = Theme,
    setAlphaHeld = function(held)
      case.held[#case.held + 1] = held
    end,
    refreshAlpha = function()
      case.refreshes = case.refreshes + 1
    end,
  })
  case.ghost = case.animation.ghost
  return case
end

local FRAME = 1 / 60
local SECONDS = Theme.LAYOUT.COMPACT_RIDE_SECONDS

-- Runs the panel's own clock frame by frame, as the client does.
local function tickPanel(case, seconds)
  local remaining = seconds
  while remaining > 0 and case.ghost.scripts and case.ghost.scripts.OnUpdate do
    case.ghost.scripts.OnUpdate(case.ghost, math.min(FRAME, remaining))
    remaining = remaining - FRAME
  end
end

return function()
  -- test_opening_hides_the_real_window_and_starts_the_panel_on_the_icon
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    assert(case.held[1] == true, "the alpha ticker keeps its hands off")
    assert(case.frame:GetAlpha() == 0, "the real window waits, full size and unseen")
    step(0, 0)
    assert(case.ghost:IsShown(), "the panel shows")
    assert(case.ghost.width <= 1 and case.ghost.height <= 1, "starts as a point, got " .. tostring(case.ghost.width))
    local _, _, _, x, y = case.ghost:GetPoint()
    assert(x == 101 and y == 741, "at the icon's centre, got " .. tostring(x) .. "," .. tostring(y))
  end

  -- test_panel_grows_with_the_shared_clock_and_the_window_never_scales
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.25, 0.5)
    assert(case.ghost.width == 180, "half way across, got " .. tostring(case.ghost.width))
    assert(case.ghost.height == 320, "half way up, got " .. tostring(case.ghost.height))
    assert(case.frame:GetScale() == 1, "the real window is never scaled")
  end

  -- test_window_fades_in_late_over_the_panel
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.3, 0.6)
    assert(case.frame:GetAlpha() == 0, "not yet")
    step(0.9, 0.99)
    local alpha = case.frame:GetAlpha()
    assert(alpha > 0 and alpha < 0.8, "fading in, got " .. tostring(alpha))
  end

  -- test_panel_stays_solid_under_the_window_until_it_is_nearly_in
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.7, 0.97)
    assert(case.ghost.alpha == 1, "no see-through dip mid-crossfade, got " .. tostring(case.ghost.alpha))
  end

  -- test_finishing_hands_the_window_back
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(1, 1)
    assert(not case.ghost:IsShown(), "the panel goes")
    assert(case.held[#case.held] == false, "the ticker resumes")
    assert(case.refreshes == 1, "the window's real alpha returns")
    assert(case.frame:GetAlpha() == 0.8, "at the player's opacity, got " .. tostring(case.frame:GetAlpha()))
  end

  -- test_closing_shrinks_the_panel_back_to_the_icon
  do
    local case = build()
    local step = case.animation.beginClose(case.icon)
    step(0, 0)
    assert(case.ghost:IsShown() and case.ghost.width == 360, "starts as the window")
    step(0.5, 0.5)
    assert(case.ghost.width == 180, "shrinking, got " .. tostring(case.ghost.width))
    step(0.99, 0.99)
    assert(case.ghost.width < 4 and case.ghost.height < 7, "ends as a point under the icon, got " .. tostring(case.ghost.width))
    step(1, 1)
    assert(not case.ghost:IsShown(), "gone at the icon")
  end

  -- test_the_panels_corner_never_leaves_the_round_icon
  do
    local radius = 21
    for _, begin in ipairs({ "beginOpen", "beginClose" }) do
      local case = build()
      local step = case.animation[begin](case.icon)
      for i = 0, 9 do
        local p = i / 10
        step(p, p)
        local _, _, _, x, y = case.ghost:GetPoint()
        local dx, dy = x - 101, y - 741
        assert(dx * dx + dy * dy <= radius * radius, begin .. ": corner outside the icon at p=" .. p)
      end
    end
  end

  -- test_closing_panel_stays_in_the_windows_strata
  do
    local case = build()
    case.frame:SetFrameStrata("MEDIUM")
    case.animation.beginClose(case.icon)
    assert(case.ghost:GetFrameStrata() == "MEDIUM", "a window behind the map closes behind the map")
    assert(case.ghost:GetFrameLevel() == 1990, "under the button")
  end

  -- test_opening_panel_follows_the_raised_window
  do
    local case = build()
    case.frame:SetFrameStrata("MEDIUM")
    case.animation.beginClose(case.icon)
    case.frame:SetFrameStrata("HIGH")
    case.animation.beginOpen(case.icon)
    assert(case.ghost:GetFrameStrata() == "HIGH", "with the window")
  end

  -- test_closing_mid_open_releases_the_window
  do
    local case = build()
    case.animation.beginOpen(case.icon)
    case.animation.beginClose(case.icon)
    assert(case.held[#case.held] == false, "a hidden window must not stay held")
  end

  -- test_finish_settles_a_running_open
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.2, 0.4)
    case.animation.finish()
    assert(not case.ghost:IsShown() and case.frame:GetAlpha() == 0.8, "settled")
    step(0.6, 0.9)
    assert(not case.ghost:IsShown(), "a stale step does nothing")
  end

  -- test_panel_sits_under_the_window_and_ignores_the_mouse
  do
    local case = build()
    assert(case.ghost:GetFrameLevel() < 2000, "below the raised window")
    assert(case.ghost.mouseEnabled ~= true, "clicks pass through")
  end

  -- test_stub_frames_without_edges_are_safe
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", "Window", nil)
    local animation = WindowGrowAnimation.Attach(frame, {
      factory = factory,
      parent = factory.CreateFrame("Frame", "UIParent", nil),
      theme = Theme,
      setAlphaHeld = function() end,
      refreshAlpha = function() end,
    })
    local step = animation.beginOpen(factory.CreateFrame("Button", "Fab", nil))
    step(0.5, 0.5)
    step(1, 1)
  end

  -- test_play_shows_the_panel_even_when_the_source_has_no_rect
  do
    local case = build()
    local bare = case.factory.CreateFrame("Button", "Bare", case.parent) -- no GetLeft: the step cannot place the panel
    case.animation.play(case.animation.beginOpen(bare))
    assert(case.ghost:IsShown(), "a hidden panel never ticks in the client, so play shows it")
    assert(case.ghost.scripts.OnUpdate ~= nil, "and the panel owns the clock")
  end

  -- test_a_panel_the_step_cannot_place_stays_unseen
  do
    for _, begin in ipairs({ "beginOpen", "beginClose" }) do
      local case = build()
      case.animation.play(case.animation.beginOpen(case.icon))
      tickPanel(case, SECONDS + 0.05) -- the panel keeps this run's last spot and size
      local bare = case.factory.CreateFrame("Button", "Bare", case.parent)
      case.animation.play(case.animation[begin](bare))
      tickPanel(case, FRAME * 3)
      assert(case.ghost.alpha == 0, begin .. ": not drawn at the last run's spot, got " .. tostring(case.ghost.alpha))
      tickPanel(case, SECONDS)
      assert(case.frame:GetAlpha() == 0.8, begin .. ": the window still ends at the player's opacity")
    end
  end

  -- test_play_drives_an_open_to_the_end_on_the_panel_clock
  do
    local case = build()
    case.animation.play(case.animation.beginOpen(case.icon))
    assert(case.ghost:IsShown() and case.ghost.width <= 1, "starts as a point")
    tickPanel(case, FRAME)
    assert(case.ghost.width > 1, "grows on the first tick, got " .. tostring(case.ghost.width))
    tickPanel(case, SECONDS + 0.05)
    assert(case.ghost.scripts.OnUpdate == nil, "the clock stops")
    assert(not case.ghost:IsShown(), "the panel goes")
    assert(case.held[#case.held] == false and case.refreshes == 1, "the window is handed back")
    assert(case.frame:GetAlpha() == 0.8, "at the player's opacity, got " .. tostring(case.frame:GetAlpha()))
  end

  -- test_play_drives_a_close_to_the_end_on_the_panel_clock
  do
    local case = build()
    case.animation.play(case.animation.beginClose(case.icon))
    assert(case.ghost:IsShown() and case.ghost.width == 360, "starts as the window")
    tickPanel(case, SECONDS + 0.05)
    assert(case.ghost.scripts.OnUpdate == nil and not case.ghost:IsShown(), "gone at the icon, clock stopped")
    assert(case.frame:GetAlpha() == 0.8, "the hidden window's alpha is untouched")
  end

  -- test_a_new_run_or_finish_stops_the_old_panel_clock
  do
    for _, name in ipairs({ "beginOpen", "beginClose", "finish" }) do
      local case = build()
      case.animation.play(case.animation.beginOpen(case.icon))
      tickPanel(case, FRAME)
      case.animation[name](case.icon)
      assert(case.ghost.scripts.OnUpdate == nil, name .. ": the superseded clock must stop")
      if name ~= "beginOpen" then -- a new open holds the window again, by design
        assert(case.held[#case.held] == false, name .. ": the window is not left held")
      end
    end
  end

  -- test_finish_after_play_leaves_the_window_at_full_alpha
  do
    local case = build()
    case.animation.play(case.animation.beginOpen(case.icon))
    tickPanel(case, FRAME * 3)
    case.animation.finish()
    assert(case.frame:GetAlpha() == 0.8 and not case.ghost:IsShown(), "settled at the player's opacity")
  end
end
