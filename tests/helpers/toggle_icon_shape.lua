-- Shared by the toggle icon shape tests: builds the widget with a chosen
-- shape, flips EllesmereUI on, tells the round and square glow art apart,
-- and checks where a region is anchored (on the 1.15x box or the button).
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

local function near(a, b)
  return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.001
end

local function pointIs(p, point, frame, x, y)
  return type(p) == "table" and p[1] == point and p[2] == frame and p[3] == point and near(p[4], x) and near(p[5], y)
end

-- True when `region` sits on the box `outset` past each edge of `frame`,
-- anchored by its top-left and bottom-right corners (IconBorder.PlaceOnBox).
local function onBox(region, frame, outset)
  local points = region.points
  return region.allPoints == nil
    and type(points) == "table"
    and #points == 2
    and pointIs(points[1], "TOPLEFT", frame, -outset, outset)
    and pointIs(points[2], "BOTTOMRIGHT", frame, outset, -outset)
end

-- True when `region` covers exactly `frame` (SetAllPoints, no other anchor).
local function coversButton(region, frame)
  return region.allPoints == frame and region.points == nil
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
  near = near,
  onBox = onBox,
  coversButton = coversButton,
  withEllesmere = withEllesmere,
  fillsButton = fillsButton,
  fillsWithSquareGlow = fillsWithSquareGlow,
  iconWithShape = iconWithShape,
}
