-- The widget shape setting ("circle" or "square") decides the look, on any
-- theme: a missing getter or any other value draws the circle.
local FakeUI = require("tests.helpers.fake_ui")
local AnimatedFactory = require("tests.helpers.animated_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local Bridge = require("WhisperMessenger.UI.Theme.EllesmereBridge")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local PulseGlow = require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")

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

local function edgesShown(edges, shown)
  for side, edge in pairs(edges) do
    if (edge.shown == true) ~= shown then
      return false, side
    end
  end

  return true
end

-- The bubble-shaped glow, centred on the glyph and BUBBLE_GLOW_SCALE times its size.
local function onBubbles(texture, glyph)
  local point = texture.point or {}
  return texture.texturePath == SquareLook.BUBBLE_GLOW_TEXTURE
    and point[1] == "CENTER"
    and point[2] == glyph
    and texture.width == glyph.width * SquareLook.BUBBLE_GLOW_SCALE
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

-- shape: "circle" | "square" | any value | a function returning one
local function iconWithShape(shape, options, factory)
  options = options or {}
  options.getWidgetShape = type(shape) == "function" and shape or function()
    return shape
  end

  return ToggleIcon.Create(factory or FakeUI.NewFactory(), options)
end

return function()
  Theme.SetPreset(Theme.DEFAULT_PRESET)

  -- test_square_works_on_any_theme_without_ellesmere
  do
    Theme.SetPreset("wow_default")
    local icon = iconWithShape("square")
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "square fill on wow_default")
    assert(edgesShown(icon.squareEdges, true), "1px edge shown")
    Theme.SetPreset("elvui_dark")
    icon.refreshTheme()
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "preset change keeps the square")
  end

  -- test_ellesmere_theme_draws_a_circle_unless_square_is_picked
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = iconWithShape("circle")
    assert(icon.background.texturePath == ROUND_BG, "circle on EllesmereUI, got " .. tostring(icon.background.texturePath))
    assert(edgesShown(icon.squareEdges, false), "no square edge")
    assert(ToggleIcon.Create(FakeUI.NewFactory(), {}).background.texturePath == ROUND_BG, "no getter reads circle")
  end)

  -- test_junk_shape_draws_a_circle
  do
    Theme.SetPreset("wow_default")
    for _, junk in ipairs({ "hexagon", 5, true }) do
      local icon = iconWithShape(junk)
      assert(icon.background.texturePath == ROUND_BG, "junk shape " .. tostring(junk) .. " draws a circle")
      assert(edgesShown(icon.squareEdges, false), "no edge for junk shape")
    end
  end

  -- test_shape_change_switches_the_look_live
  do
    Theme.SetPreset("wow_default")
    local shape = "circle"
    local icon = iconWithShape(function()
      return shape
    end)
    shape = "square"
    icon.refreshTheme()
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE and edgesShown(icon.squareEdges, true), "square after the change")
    shape = "circle"
    icon.refreshTheme()
    assert(icon.background.texturePath == ROUND_BG and edgesShown(icon.squareEdges, false), "circle again")
  end

  -- test_shape_change_keeps_the_unread_pulse_running
  do
    Theme.SetPreset("wow_default")
    local factory = AnimatedFactory.newAnimatedFactory()
    local shape = "circle"
    local icon = iconWithShape(function()
      return shape
    end, {}, factory)
    icon.setUnreadCount(2)
    local function pulsing()
      for _, group in ipairs(factory.groups) do
        if group.playing then
          return true
        end
      end

      return false
    end
    assert(pulsing(), "pulse running before the change")
    assert(fillsButton(icon.pulseTexture, icon.frame), "round pulse art on the circle")
    shape = "square"
    icon.refreshTheme()
    assert(pulsing(), "pulse still running on square")
    assert(onBubbles(icon.pulseTexture, icon.label), "pulse sits around the bubbles on square")
    shape = "circle"
    icon.refreshTheme()
    assert(pulsing() and fillsButton(icon.pulseTexture, icon.frame), "pulse back on the circle art, still running")
  end

  -- test_shape_change_keeps_the_hover_lift
  do
    Theme.SetPreset("wow_default")
    local shape = "circle"
    local icon = iconWithShape(function()
      return shape
    end)
    icon.frame:GetScript("OnEnter")(icon.frame)
    shape = "square"
    icon.refreshTheme()
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "still hovered on the square")
    shape = "circle"
    icon.refreshTheme()
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "lift back on the circle")
  end

  -- test_idle_gray_follows_the_shape_not_the_theme (the square keeps DESAT_GREY)
  do
    Theme.SetPreset("wow_default")
    local shape = "square"
    local icon = iconWithShape(function()
      return shape
    end, {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_GREY), "square grays with DESAT_GREY")
    shape = "circle"
    icon.refreshTheme()
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "circle grays with DESAT_BACK")
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
