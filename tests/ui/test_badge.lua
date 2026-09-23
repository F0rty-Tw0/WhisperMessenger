local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Badge = require("WhisperMessenger.UI.Badge")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)

  -- test_default_size_is_icon_badge_size
  local default = Badge.Create(factory, parent)
  local size = Theme.LAYOUT.ICON_BADGE_SIZE
  assert(default.frame.width == size and default.frame.height == size, "default badge should use ICON_BADGE_SIZE")

  -- test_custom_size_sets_frame_size
  local small = Badge.Create(factory, parent, { size = 14 })
  assert(small.frame.width == 14 and small.frame.height == 14, "custom size should set the frame size")

  -- test_outline_only_when_requested
  assert(default.outline == nil, "outline should be off by default")
  local outlined = Badge.Create(factory, parent, { outline = true })
  assert(outlined.outline ~= nil, "outline should exist when opts.outline is true")

  -- test_starts_hidden
  assert(default.frame.shown == false, "badge should start hidden")

  -- test_set_count_formats_and_shows
  default.setCount(3)
  assert(default.label.text == "3", "count 3 should read 3")
  assert(default.frame.shown == true, "badge should show with a count")
  default.setCount(150)
  assert(default.label.text == "99+", "count over 99 should read 99+")

  -- test_set_count_zero_hides
  default.setCount(0)
  assert(default.frame.shown == false, "badge should hide at 0")
  default.setCount(5)
  default.setCount(nil)
  assert(default.frame.shown == false, "badge should hide on nil count")

  -- test_paint_uses_badge_colors
  Theme.SetPreset("plumber_warm")
  default.paint()
  local bg, text = Theme.BadgeColors()
  assert(colorsMatch(default.background.vertexColor, bg), "paint should color the background")
  assert(colorsMatch(default.label.textColor, text), "paint should color the label")

  -- test_circles_unsnapped_and_label_shadowless
  for _, tex in ipairs({ outlined.background, outlined.outline }) do
    assert(tex.snapToPixelGrid == false, "badge circle should not snap to pixel grid")
    assert(tex.texelSnappingBias == 0, "badge circle should not bias texel snapping")
  end
  local shadow = outlined.label.shadowOffset
  assert(shadow and shadow[1] == 0 and shadow[2] == 0, "badge label shadow should be off")

  Theme.SetPreset(previousPreset)
  print("PASS: test_badge")
end
