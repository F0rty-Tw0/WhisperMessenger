local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

-- The real icon hands the window's move to its own saved position, unless locked.

local function build(locked)
  local factory = FakeUI.NewFactory()
  local slot = factory.CreateFrame("Frame", "Slot", factory.CreateFrame("Frame", "UIParent", nil))
  rawset(slot, "GetCenter", function()
    return 300, 700
  end)
  local case = { saved = 0 }
  case.icon = ToggleIcon.Create(factory, {
    onPositionChanged = function()
      case.saved = case.saved + 1
    end,
    getIsLocked = function()
      return locked
    end,
  })
  case.icon.rideTo({ region = slot, relativePoint = "CENTER", x = 0, y = 0, scale = 2, level = 3000 }, nil, true)
  rawset(case.icon.frame, "GetCenter", function()
    return 150, 350
  end)
  return case
end

return function()
  -- test_adopting_the_ride_position_saves_the_icons_position
  do
    local case = build(false)
    case.icon.adoptRidePosition()
    assert(case.saved == 1, "one save, got " .. case.saved)
  end

  -- test_a_locked_icon_never_saves_a_ride_position
  do
    local case = build(true)
    case.icon.adoptRidePosition()
    assert(case.saved == 0, "locked, got " .. case.saved)
  end
end
