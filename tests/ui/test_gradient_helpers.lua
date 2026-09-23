local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Base = require("WhisperMessenger.UI.Helpers.Base")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")

local function gradientTexture()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local texture = frame:CreateTexture(nil, "ARTWORK")
  rawset(texture, "SetGradient", function(self, orientation, minColor, maxColor)
    self.gradient = { orientation = orientation, from = minColor, to = maxColor }
  end)
  return texture, frame
end

return function()
  local previousPreset = Theme.GetPreset()
  local previousCreateColor = _G.CreateColor
  rawset(_G, "CreateColor", function(r, g, b, a)
    return { r = r, g = g, b = b, a = a }
  end)

  -- test_vertical_fade_is_transparent_at_bottom
  do
    local texture = gradientTexture()
    Base.applyVerticalFade(texture, { 1, 1, 1, 0.05 })
    local g = texture.gradient
    assert(g.orientation == "VERTICAL", "vertical fade uses VERTICAL orientation")
    assert(g.from.a == 0, "bottom (min) is transparent")
    assert(g.to.a == 1, "top (max) keeps the base colour's full alpha")
    assert(texture.color[4] == 0.05, "base texture is the intended colour, not opaque white")
  end

  -- test_dropped_gradient_leaves_intended_colour
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", nil, nil)
    local texture = frame:CreateTexture(nil, "ARTWORK")
    rawset(texture, "SetGradient", function()
      error("gradient not supported")
    end)
    Base.applyHorizontalFade(texture, { 0.2, 0.4, 0.6, 0.15 })
    local c = texture.color
    assert(c[1] == 0.2 and c[2] == 0.4 and c[3] == 0.6 and c[4] == 0.15, "worst case is the flat intended colour")
  end

  -- test_horizontal_fade_unchanged
  do
    local texture = gradientTexture()
    Base.applyHorizontalFade(texture, { 0.1, 0.2, 0.3, 0.15 })
    local g = texture.gradient
    assert(g.orientation == "HORIZONTAL" and g.from.a == 1 and g.to.a == 0, "horizontal fade: left full -> right transparent")
    local c = texture.color
    assert(c[1] == 0.1 and c[4] == 0.15, "horizontal base is the intended colour")
  end

  -- test_sheen_is_subtle_on_every_preset
  do
    Theme.SetPreset("wow_default")
    local _, frame = gradientTexture()
    local sheen = Shapes.createSheen(frame)
    Shapes.applySheen(sheen)
    assert(sheen.shown == true, "modern: sheen shown")
    local alpha = sheen.color and sheen.color[4]
    assert(alpha and alpha >= 0.04 and alpha <= 0.06, "sheen top alpha 0.04-0.06 (flat fallback in fake UI)")
    Theme.SetPreset("wow_native")
    Shapes.applySheen(sheen)
    assert(sheen.shown == true, "azeroth: sheen shown too")
  end

  rawset(_G, "CreateColor", previousCreateColor)
  Theme.SetPreset(previousPreset)
  print("PASS: test_gradient_helpers")
end
