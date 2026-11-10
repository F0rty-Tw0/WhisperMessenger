-- The widget shape setting ("circle" or "square") decides the look, on any
-- theme: a missing getter or any other value draws the circle.
local FakeUI = require("tests.helpers.fake_ui")
local AnimatedFactory = require("tests.helpers.animated_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")

local Shape = require("tests.helpers.toggle_icon_shape")
local ROUND_BG = Shape.ROUND_BG
local sameColor = Shape.sameColor
local withEllesmere = Shape.withEllesmere
local fillsButton = Shape.fillsButton
local fillsWithSquareGlow = Shape.fillsWithSquareGlow
local iconWithShape = Shape.iconWithShape

return function()
  Theme.SetPreset(Theme.DEFAULT_PRESET)

  -- test_square_works_on_any_theme_without_ellesmere
  do
    Theme.SetPreset("wow_default")
    local icon = iconWithShape("square")
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "square fill on wow_default")
    assert(icon.squareFrame.shown == true, "square frame shown")
    Theme.SetPreset("elvui_dark")
    icon.refreshTheme()
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "preset change keeps the square")
  end

  -- test_ellesmere_theme_draws_a_circle_unless_square_is_picked
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = iconWithShape("circle")
    assert(icon.background.texturePath == ROUND_BG, "circle on EllesmereUI, got " .. tostring(icon.background.texturePath))
    assert(icon.squareFrame.shown == false, "no square frame")
  end)

  -- test_missing_shape_getter_draws_a_circle
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
    assert(icon.background.texturePath == ROUND_BG, "no getter reads circle")
  end)

  -- test_junk_shape_draws_a_circle
  do
    Theme.SetPreset("wow_default")
    for _, junk in ipairs({ "hexagon", 5, true }) do
      local icon = iconWithShape(junk)
      assert(icon.background.texturePath == ROUND_BG, "junk shape " .. tostring(junk) .. " draws a circle")
      assert(icon.squareFrame.shown == false, "no square frame for junk shape")
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
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE and icon.squareFrame.shown == true, "square after the change")
    shape = "circle"
    icon.refreshTheme()
    assert(icon.background.texturePath == ROUND_BG and icon.squareFrame.shown == false, "circle again")
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
    assert(fillsWithSquareGlow(icon.pulseTexture, icon.frame), "pulse glows along the square edge")
    shape = "circle"
    icon.refreshTheme()
    assert(pulsing() and fillsButton(icon.pulseTexture, icon.frame), "pulse back on the circle art, still running")
    shape = "square"
    icon.refreshTheme()
    assert(pulsing() and fillsWithSquareGlow(icon.pulseTexture, icon.frame), "square edge art again, still running")
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
