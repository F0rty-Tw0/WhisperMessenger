local IconPosition = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconPosition")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  -- test_reset_while_riding_changes_home_not_the_spot_on_the_window
  do
    local frame = FakeUI.NewFactory().CreateFrame("Button", "Fab", nil)
    local homes = {}
    local icon = {
      frame = frame,
      isRiding = function()
        return true
      end,
      setRideHome = function(state)
        homes[#homes + 1] = state
      end,
    }
    local state = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    assert(IconPosition.Apply(icon, state) == state, "still returns the state")
    assert(homes[1] == state, "home moves")
    assert(frame.point == nil, "the riding button stays on the window")
  end
end
