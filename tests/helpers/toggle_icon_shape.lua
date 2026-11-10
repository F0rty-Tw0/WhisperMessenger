-- Shared by the toggle icon shape tests: builds the widget with a chosen
-- shape, flips EllesmereUI on, and tells the round and square glow art apart.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Bridge = require("WhisperMessenger.UI.Theme.EllesmereBridge")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local PulseGlow = require("WhisperMessenger.UI.ToggleIcon.PulseGlow")

local ROUND_BG = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function withEllesmere(fn)
  rawset(_G, "EllesmereUI", {
    RegisterSkin = function()
      return true
    end,
  })
  Bridge._Reset()
  local ok, err = pcall(fn)
  Theme.SetPreset(Theme.DEFAULT_PRESET)
  rawset(_G, "EllesmereUI", nil)
  Bridge._Reset()
  if not ok then
    error(err, 0)
  end
end

-- The round pulse art, stretched over its glow frame, which covers the whole button.
local function fillsButton(texture, button)
  local glowFrame = texture.allPoints
  return texture.texturePath == PulseGlow.TEXTURE
    and texture.point == nil
    and glowFrame ~= nil
    and glowFrame == texture.parent
    and glowFrame.allPoints == button
end

-- The square edge-glow art, stretched over the pulse's glow frame, which covers the whole button.
local function fillsWithSquareGlow(texture, button)
  local glowFrame = texture.allPoints
  return texture.texturePath == SquareLook.SQUARE_GLOW_TEXTURE
    and texture.point == nil
    and glowFrame ~= nil
    and glowFrame == texture.parent
    and glowFrame.allPoints == button
end

-- shape: "circle" | "square" | any value | a function returning one
local function iconWithShape(shape, options, factory)
  options = options or {}
  options.getWidgetShape = type(shape) == "function" and shape or function()
    return shape
  end
  return ToggleIcon.Create(factory or FakeUI.NewFactory(), options)
end

return {
  ROUND_BG = ROUND_BG,
  sameColor = sameColor,
  withEllesmere = withEllesmere,
  fillsButton = fillsButton,
  fillsWithSquareGlow = fillsWithSquareGlow,
  iconWithShape = iconWithShape,
}
