-- The square shape sits on a solid square backdrop in the icon's background
-- color, like the circle's dark disc, so the ground never shows through the
-- slot fill behind the bubbles.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function iconWith(shape, showBackground)
  return ToggleIcon.Create(FakeUI.NewFactory(), {
    getWidgetShape = function()
      return shape
    end,
    getIconBackground = function()
      return showBackground
    end,
  })
end

return function()
  -- test_square_shows_an_opaque_backdrop_in_the_icon_background_color
  do
    local icon = iconWith("square", true)
    local backdrop = icon.squareBackdrop
    assert(backdrop ~= nil, "the square has a backdrop")
    assert(backdrop:IsShown(), "the backdrop shows on the square")
    assert(backdrop.texturePath == SquareLook.SQUARE_TEXTURE, "square-shaped, got " .. tostring(backdrop.texturePath))
    assert(sameColor(backdrop.vertexColor, Theme.COLORS.toggle_icon_bg), "painted like the circle's disc")
    assert((backdrop.vertexColor[4] or 1) == 1, "opaque: the ground does not show through")
  end

  -- test_circle_has_no_square_backdrop
  do
    local icon = iconWith("circle", true)
    assert(not icon.squareBackdrop:IsShown(), "the circle keeps its own disc")
  end

  -- test_background_option_off_hides_the_square_backdrop
  do
    local icon = iconWith("square", false)
    assert(not icon.squareBackdrop:IsShown(), "no background: bubbles only")
  end

  print("PASS: test_toggle_icon_square_backdrop")
end
