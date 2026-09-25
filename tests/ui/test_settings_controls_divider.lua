-- Shared settings divider: the section-header hairline look, free-standing.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")
local Divider = require("WhisperMessenger.UI.Shared.SettingsControls.Divider")

local function sameRgb(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

return function()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)

  -- test_divider_is_two_snapped_pixel_hairlines_meeting_in_the_middle
  do
    local divider = Divider.Create(frame)
    for _, line in ipairs({ divider.left, divider.right }) do
      assert(line.height == Shapes.hairlineThickness(line, 1), "divider halves are pixel hairlines")
      assert(line.snapToPixelGrid == true, "divider halves snap to the pixel grid")
    end
    local point, relativeTo, relativePoint = divider.right:GetPoint()
    assert(point == "LEFT" and relativeTo == divider.left and relativePoint == "RIGHT", "right half starts where the left half ends")
  end

  -- test_set_width_splits_the_span_between_the_halves
  do
    local divider = Divider.Create(frame)
    divider.setWidth(300)
    assert(divider.left.width == 150 and divider.right.width == 150, "each half spans half the width")
  end

  -- test_apply_theme_uses_the_section_header_line_colour
  do
    local divider = Divider.Create(frame)
    divider.applyTheme(Theme)
    local expected = Theme.COLORS.contacts_border_right or Theme.COLORS.divider
    assert(sameRgb(divider.left.color, expected), "left half uses the header line colour")
    assert(sameRgb(divider.right.color, expected), "right half uses the header line colour")
  end
end
