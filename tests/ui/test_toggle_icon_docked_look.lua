-- While the button rides the window it wears the default circle (border,
-- background and themed all on) whatever the saved look; landing brings the
-- saved look back. Transparency and desaturation keep applying.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")
local DockedLook = require("WhisperMessenger.UI.ToggleIcon.DockedLook")

local ROUND_BG = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local WHITE = { 1, 1, 1, 1 }

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

-- state is read live; nil fields mean the defaults (circle, all on, opaque).
local function build(state)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:Show()
  local icon = ToggleIcon.Create(factory, {
    parent = parent,
    getWidgetShape = function()
      return state.shape
    end,
    getIconBorder = function()
      return state.border
    end,
    getIconBackground = function()
      return state.background
    end,
    getIconBorderThemed = function()
      return state.themed
    end,
    getIconDesaturated = function()
      return state.desaturated == true
    end,
    getWidgetTransparency = function()
      return state.transparency or 0
    end,
  })
  icon.frame:Show()
  local target = { region = factory.CreateFrame("Frame", nil, parent), relativePoint = "CENTER", x = 0, y = 0, scale = 2, level = 3000 }
  return icon, target
end

local function isDefaultCircle(icon)
  return icon.background.texturePath == ROUND_BG and icon.background.shown == true and icon.ring.shown == true and icon.squareFrame.shown == false
end

return function()
  Theme.SetPreset("wow_default")

  local function test_docked_square_with_border_and_background_off_wears_the_default_circle()
    local icon, target = build({ shape = "square", border = false, background = false })
    assert(icon.ring.shown == false and icon.squareFrame.shown == false and icon.background.shown == false, "floating: no border, no background")
    icon.rideTo(target)
    assert(isDefaultCircle(icon), "docked: round, ring and background on, got " .. tostring(icon.background.texturePath))
  end

  local function test_landing_home_brings_the_saved_look_back()
    local icon, target = build({ shape = "square", border = false, background = false })
    icon.rideTo(target)
    icon.rideHome()
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "square again after landing")
    assert(icon.ring.shown == false and icon.squareFrame.shown == false and icon.background.shown == false, "border and background off again")
  end

  local function test_docked_square_with_everything_on_turns_round_and_is_square_again_at_home()
    local icon, target = build({ shape = "square" })
    assert(icon.squareFrame.shown == true and icon.ring.shown == false, "floating square wears the square frame")
    icon.rideTo(target)
    assert(isDefaultCircle(icon), "docked: the round look, no square frame")
    icon.rideHome()
    assert(icon.squareFrame.shown == true and icon.ring.shown == false, "square frame back at home")
  end

  local function test_docked_look_is_themed_even_when_the_saved_border_is_gold()
    local icon, target = build({ shape = "circle", themed = false })
    assert(sameColor(icon.ring.vertexColor, WHITE), "floating: gold art, untinted")
    icon.rideTo(target)
    assert(sameColor(icon.ring.vertexColor, Theme.COLORS.accent), "docked: tinted to the theme accent")
    icon.rideHome()
    assert(sameColor(icon.ring.vertexColor, WHITE), "gold again at home")
  end

  local function test_settings_refresh_while_docked_keeps_the_circle()
    local state = { shape = "circle" }
    local icon, target = build(state)
    icon.rideTo(target)
    state.shape, state.border, state.background = "square", false, false
    icon.refreshTheme()
    assert(isDefaultCircle(icon), "a shape, border or background change while docked leaves the corner circle alone")
    icon.rideHome()
    assert(
      icon.background.texturePath == SquareLook.SQUARE_TEXTURE and icon.ring.shown == false and icon.background.shown == false,
      "the changed settings show at home"
    )
  end

  local function test_transparency_and_desaturation_still_apply_while_docked()
    local icon, target = build({ shape = "square", desaturated = true, transparency = 0.4 })
    icon.setUnreadCount(0)
    icon.rideTo(target)
    assert(math.abs(icon.frame:GetAlpha() - 0.6) < 0.001, "transparency untouched, got " .. tostring(icon.frame:GetAlpha()))
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "grayed as the circle grays, not the square's gray")
  end

  local function test_a_hovered_button_gets_the_circle_hover_fill_when_it_docks()
    local icon, target = build({ shape = "square" })
    icon.frame:GetScript("OnEnter")(icon.frame)
    icon.rideTo(target)
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "circle hover fill, not the square's slot fill")
  end

  local function test_set_docked_repaints_only_when_the_flag_changes()
    local icon = build({ shape = "square" })
    local repaints = 0
    local setTexture = icon.background.SetTexture
    icon.background.SetTexture = function(self, path)
      repaints = repaints + 1
      return setTexture(self, path)
    end
    icon.setDocked(true)
    assert(repaints == 1, "one repaint on the change, got " .. repaints)
    icon.setDocked(true)
    assert(repaints == 1, "none when unchanged, got " .. repaints)
    icon.setDocked(false)
    assert(repaints == 2, "one repaint back, got " .. repaints)
  end

  local function test_wrap_returns_the_default_circle_docked_and_the_saved_values_floating()
    local docked = true
    local wrapped = DockedLook.Wrap({
      getWidgetShape = function()
        return "square"
      end,
      getIconBorder = function()
        return false
      end,
      getIconBackground = function()
        return false
      end,
      getIconBorderThemed = function()
        return false
      end,
    }, function()
      return docked
    end)
    assert(wrapped.getWidgetShape() == "circle", "docked shape")
    assert(wrapped.getIconBorder() == true and wrapped.getIconBackground() == true and wrapped.getIconBorderThemed() == true, "docked defaults")
    docked = false
    assert(wrapped.getWidgetShape() == "square", "floating shape")
    assert(
      wrapped.getIconBorder() == false and wrapped.getIconBackground() == false and wrapped.getIconBorderThemed() == false,
      "floating saved values"
    )
    local bare = DockedLook.Wrap({}, function()
      return false
    end)
    assert(bare.getWidgetShape() == nil and bare.getIconBorder() == nil, "a missing getter stays nil when floating")
  end

  test_docked_square_with_border_and_background_off_wears_the_default_circle()
  test_landing_home_brings_the_saved_look_back()
  test_docked_square_with_everything_on_turns_round_and_is_square_again_at_home()
  test_docked_look_is_themed_even_when_the_saved_border_is_gold()
  test_settings_refresh_while_docked_keeps_the_circle()
  test_transparency_and_desaturation_still_apply_while_docked()
  test_a_hovered_button_gets_the_circle_hover_fill_when_it_docks()
  test_set_docked_repaints_only_when_the_flag_changes()
  test_wrap_returns_the_default_circle_docked_and_the_saved_values_floating()

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
