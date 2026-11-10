local IconRide = require("WhisperMessenger.UI.ToggleIcon.IconRide")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local SECONDS = Theme.LAYOUT.COMPACT_RIDE_SECONDS
local FRAME = 1 / 60

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Button", "Fab", parent)
  frame:SetSize(42, 42)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 40)
  frame:SetFrameStrata("HIGH")
  frame:SetFrameLevel(5)
  parent:Show()
  frame:Show()
  local case = { frame = frame, levels = {} }
  rawset(frame, "GetCenter", function()
    local _, _, _, x, y = frame:GetPoint()
    return x, y
  end)
  local region = factory.CreateFrame("Frame", nil, parent)
  rawset(region, "GetCenter", function()
    return 300, 700
  end)
  case.target = { region = region, relativePoint = "CENTER", x = 0, y = 0, scale = 2, level = 3000 }
  case.ride = IconRide.Create(frame, {
    theme = Theme,
    parent = parent,
    onLevel = function(level)
      case.levels[#case.levels + 1] = level
    end,
  })
  return case
end

-- Runs the glide frame by frame, as the client does.
local function tick(case, seconds)
  local remaining = seconds
  while remaining > 0 and case.frame.scripts.OnUpdate do
    case.frame.scripts.OnUpdate(case.frame, math.min(FRAME, remaining))
    remaining = remaining - FRAME
  end
end

return function()
  -- test_set_home_strata_at_home_applies_now_and_keeps_level_and_badge
  do
    local case = build()
    case.ride.setHomeStrata("LOW")
    assert(case.frame:GetFrameStrata() == "LOW", "applies now, got " .. tostring(case.frame:GetFrameStrata()))
    assert(case.frame:GetFrameLevel() == 5, "level unchanged, got " .. tostring(case.frame:GetFrameLevel()))
    assert(case.levels[#case.levels] == 5, "the badge is told the unchanged level, got " .. tostring(case.levels[#case.levels]))
  end

  -- test_set_home_strata_while_riding_keeps_the_window_strata_until_landing
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.ride.setStrata("MEDIUM")
    case.ride.setHomeStrata("LOW")
    assert(case.frame:GetFrameStrata() == "MEDIUM", "still on the window's strata, got " .. tostring(case.frame:GetFrameStrata()))
    case.ride.rideHome()
    tick(case, SECONDS + 0.01)
    assert(case.frame:GetFrameStrata() == "LOW", "landing restores the new strata, got " .. tostring(case.frame:GetFrameStrata()))
  end

  -- test_set_home_strata_during_the_return_glide_lands_on_the_new_strata
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.ride.rideHome()
    assert(not case.ride.isRiding(), "gliding back, no longer riding")
    case.ride.setHomeStrata("BACKGROUND")
    tick(case, SECONDS + 0.01)
    assert(case.frame:GetFrameStrata() == "BACKGROUND", "landed on the new strata, got " .. tostring(case.frame:GetFrameStrata()))
  end

  -- test_resolve_strata_unknown_value_is_high
  assert(IconRide.ResolveStrata(nil) == "HIGH", "nil is HIGH")
  assert(IconRide.ResolveStrata("TOOLTIP") == "HIGH", "TOOLTIP is HIGH")
  assert(IconRide.ResolveStrata(5) == "HIGH", "a number is HIGH")
  assert(IconRide.ResolveStrata("BACKGROUND") == "BACKGROUND", "BACKGROUND stays")
  assert(IconRide.ResolveStrata("LOW") == "LOW", "LOW stays")
  assert(IconRide.ResolveStrata("MEDIUM") == "MEDIUM", "MEDIUM stays")
end
