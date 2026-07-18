local FakeUI = require("tests.helpers.fake_ui")
local DateSeparator = require("WhisperMessenger.UI.ChatBubble.DateSeparator")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  local innerFactory = FakeUI.NewFactory()
  local parent = innerFactory.CreateFrame("Frame", "Pane", nil)
  parent:SetSize(400, 600)
  local ts = os.time({ year = 2026, month = 3, day = 19, hour = 12, min = 0, sec = 0 })

  -- test_divider_lines_take_current_theme_color_on_reuse
  do
    -- Model the frame pool: the factory hands back the same frame on the
    -- second render, which is exactly when the cached-region branch runs.
    local pooled
    local poolingFactory = {
      CreateFrame = function(...)
        if pooled == nil then
          pooled = innerFactory.CreateFrame(...)
        end
        return pooled
      end,
    }

    local frame = DateSeparator.CreateDateSeparator(poolingFactory, parent, ts, 400).frame
    assert(frame._lineLeft ~= nil and frame._lineRight ~= nil, "separator creates divider lines")

    local savedDivider = Theme.COLORS.divider
    Theme.COLORS.divider = { 0.9, 0.1, 0.1, 1 }

    local again = DateSeparator.CreateDateSeparator(poolingFactory, parent, ts, 400).frame
    assert(again == frame, "pool returns the same frame on reuse")

    local left = again._lineLeft
    assert(left.color ~= nil, "divider line has a color applied")
    assert(left.color[1] == 0.9 and left.color[2] == 0.1, "reused divider picks up the current theme color, got: " .. tostring(left.color[1]))
    local right = again._lineRight
    assert(right.color and right.color[1] == 0.9, "right divider recolors too")

    Theme.COLORS.divider = savedDivider
  end
end
