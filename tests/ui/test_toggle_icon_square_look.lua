-- The square shape draws the widget as a flat square under the square frame
-- (theme accent, or gold); the circle keeps the round look. Both show the two bubbles.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")
local ButtonLook = require("WhisperMessenger.UI.Theme.EllesmereButtonLook")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local Shape = require("tests.helpers.toggle_icon_shape")
local ROUND_BG = Shape.ROUND_BG
local sameColor = Shape.sameColor
local withEllesmere = Shape.withEllesmere
local fillsButton = Shape.fillsButton
local fillsWithSquareGlow = Shape.fillsWithSquareGlow
local iconWithShape = Shape.iconWithShape

local SLOT_BG = ButtonLook.Read().bg -- EllesmereUI's defaults: the fake has no action bars module

-- The bubble-shaped glow, centred on the glyph and BUBBLE_GLOW_SCALE times its size.
local function onBubbles(texture, glyph)
  local point = texture.point or {}
  return texture.texturePath == SquareLook.BUBBLE_GLOW_TEXTURE
    and point[1] == "CENTER"
    and point[2] == glyph
    and texture.width == glyph.width * SquareLook.BUBBLE_GLOW_SCALE
end

return function()
  -- test_ellesmere_preset_draws_a_square_widget
  do
    local icon = iconWithShape("square", {})
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "square fill, got " .. tostring(icon.background.texturePath))
    assert(icon.label.texturePath == SquareLook.GLYPH_TEXTURE, "ring-free glyph, got " .. tostring(icon.label.texturePath))
    assert(icon.ring.shown == false, "no ring on the square; the square frame takes its place")
    assert(sameColor(icon.background.vertexColor, SLOT_BG), "EllesmereUI's slot background")
    assert(icon.accentGlyph.shown == true, "accent back bubble shown")
    assert(icon.accentGlyph.texturePath == SquareLook.ACCENT_GLYPH_TEXTURE, "back bubble art")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "back bubble in the accent color")
  end

  -- test_accent_bubble_grays_out_with_the_icon
  do
    local icon = iconWithShape("square", {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_GREY), "gray while desaturated")
    icon.setUnreadCount(2)
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "accent again with unread whispers")
  end

  -- test_desaturating_leaves_the_white_bubble_and_background_alone
  do
    local icon = iconWithShape("square", {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(sameColor(icon.label.vertexColor, Theme.COLORS.toggle_icon_glyph), "white bubble keeps its color")
    assert(icon.label.desaturated ~= true, "white bubble not desaturated")
    assert(sameColor(icon.background.vertexColor, SLOT_BG), "background keeps its color")
    icon.frame:GetScript("OnEnter")(icon.frame)
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(sameColor(icon.background.vertexColor, SLOT_BG), "background keeps its color after a hover")
  end

  -- test_round_look_grays_only_the_back_bubble
  do
    Theme.SetPreset("wow_default")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(icon.label.desaturated ~= true, "front bubble keeps its color")
    assert(icon.background.desaturated ~= true, "circle keeps its color")
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "back bubble grays out")
  end

  -- test_background_option_hides_the_square
  do
    local showBackground = false
    local icon = iconWithShape("square", {
      getIconBackground = function()
        return showBackground
      end,
    })
    assert(icon.background.shown == false, "no fill")
    assert(icon.squareFrame.shown == true, "frame stays without the square")
    assert(icon.accentGlyph.shown == true and icon.label.texturePath == SquareLook.GLYPH_TEXTURE, "both bubbles still shown")
    showBackground = true
    icon.refreshTheme()
    assert(icon.background.shown == true, "square back when turned on")
  end

  -- test_hover_fills_only_the_back_bubble_with_the_accent
  do
    local icon = iconWithShape("square", {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    icon.frame:GetScript("OnEnter")(icon.frame)
    assert(sameColor(icon.background.vertexColor, SLOT_BG), "square keeps its color on hover")
    assert(sameColor(icon.label.vertexColor, Theme.COLORS.toggle_icon_glyph), "white bubble keeps its color on hover")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "back bubble is exactly the accent on hover")
    assert(icon.hoverGlow.shown ~= true, "no glow while the square shows")
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_GREY), "gray again after hover")
    assert(sameColor(icon.background.vertexColor, SLOT_BG), "slot background back after hover")
  end

  -- test_square_shows_the_action_bar_hover_and_pushed_effects
  do
    local showBackground = true
    local icon = iconWithShape("square", {
      getIconBackground = function()
        return showBackground
      end,
    })
    assert(icon.squareHover.shown ~= true and icon.squarePushed.shown ~= true, "no effects at rest")
    icon.frame:GetScript("OnEnter")(icon.frame)
    assert(icon.squareHover.shown == true, "hover effect on the square")
    icon.frame:GetScript("OnMouseDown")(icon.frame)
    assert(icon.squarePushed.shown == true, "pushed effect while held")
    icon.frame:GetScript("OnMouseUp")(icon.frame)
    assert(icon.squarePushed.shown == false, "pushed effect gone on release")
    icon.frame:GetScript("OnMouseDown")(icon.frame)
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(icon.squareHover.shown == false and icon.squarePushed.shown == false, "both gone on leave")
    showBackground = false
    icon.refreshTheme()
    icon.frame:GetScript("OnEnter")(icon.frame)
    icon.frame:GetScript("OnMouseDown")(icon.frame)
    assert(icon.squareHover.shown ~= true and icon.squarePushed.shown ~= true, "no square effects without the square")
  end

  -- test_hover_glows_in_the_accent_without_the_square
  do
    local icon = iconWithShape("square", {
      getIconBackground = function()
        return false
      end,
    })
    assert(icon.hoverGlow.shown ~= true, "no glow before hover")
    icon.frame:GetScript("OnEnter")(icon.frame)
    assert(icon.hoverGlow.shown == true, "glow on hover")
    local accent = Theme.COLORS.accent
    local glow = icon.hoverGlow.vertexColor
    assert(glow[1] == accent[1] and glow[2] == accent[2] and glow[3] == accent[3], "glow in the accent color")
    assert(onBubbles(icon.hoverGlow, icon.label), "hover glow follows the bubbles")
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(icon.hoverGlow.shown == false, "glow gone after hover")
  end

  -- test_outline_around_the_bubbles_only_without_the_square
  do
    local shape = "square"
    local showBackground = false
    local icon = iconWithShape(function()
      return shape
    end, {
      getIconBackground = function()
        return showBackground
      end,
    })
    local outline = icon.glyphOutline
    assert(outline.shown == true, "outline shown without the square")
    assert(outline.texturePath == SquareLook.OUTLINE_TEXTURE and outline.allPoints == icon.label, "outline art over the glyph")
    assert(outline.vertexColor[1] == 0 and outline.vertexColor[2] == 0 and outline.vertexColor[3] == 0, "black outline")
    showBackground = true
    icon.refreshTheme()
    assert(outline.shown == false, "no outline with the square")
    showBackground = false
    shape = "circle"
    icon.refreshTheme()
    assert(outline.shown == true, "outline around the bubbles on the round widget without its circle")
  end

  -- test_unread_pulse_glows_along_the_square_edge
  do
    local shape = "square"
    local showBackground = false
    local icon = iconWithShape(function()
      return shape
    end, {
      getIconBackground = function()
        return showBackground
      end,
    })
    assert(fillsWithSquareGlow(icon.pulseTexture, icon.frame), "pulse follows the edge, got " .. tostring(icon.pulseTexture.texturePath))
    icon.applyIconSize(60)
    assert(fillsWithSquareGlow(icon.pulseTexture, icon.frame), "pulse resized with the icon")
    showBackground = true
    icon.refreshTheme()
    assert(fillsWithSquareGlow(icon.pulseTexture, icon.frame), "square shown: still along the edge")
    shape = "circle"
    icon.refreshTheme()
    assert(fillsButton(icon.pulseTexture, icon.frame), "round again on other presets")
  end

  -- test_round_widget_keeps_its_pulse
  do
    Theme.SetPreset("wow_default")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
      getIconBackground = function()
        return false
      end,
    })
    assert(fillsButton(icon.pulseTexture, icon.frame), "round widget: the usual pulse")
  end

  -- test_background_option_change_repaints_the_widget
  do
    local refreshed = 0
    local accountSettings = {}
    local onChange = SettingsHandler.Create({
      runtime = { store = { config = {} } },
      accountSettings = accountSettings,
      getIcon = function()
        return {
          refreshTheme = function()
            refreshed = refreshed + 1
          end,
        }
      end,
    })
    onChange("iconBackground", false)
    assert(accountSettings.iconBackground == false, "saved")
    assert(refreshed == 1, "widget repainted, got " .. refreshed)
  end

  -- test_other_presets_keep_the_round_widget
  do
    Theme.SetPreset("wow_default")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
    assert(icon.background.texturePath == ROUND_BG, "round fill")
    assert(icon.label.texturePath == SquareLook.GLYPH_TEXTURE, "front bubble")
    assert(icon.ring.shown == true, "the ring around the circle")
    assert(icon.squareFrame.shown == false, "no square frame on the circle")
    assert(icon.accentGlyph.shown == true, "accent back bubble")
  end

  -- test_minimap_stays_round_under_ellesmere
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {
      getIconDesaturated = function()
        return true
      end,
    })
    assert(minimap.iconTex.texturePath == SquareLook.GLYPH_TEXTURE, "minimap glyph, got " .. tostring(minimap.iconTex.texturePath))
    assert(minimap.background.texturePath == IconArt.CIRCLE_TEX, "minimap stays a circle, got " .. tostring(minimap.background.texturePath))
    minimap.setUnreadCount(0)
    assert(minimap.accentGlyph.shown == true, "minimap back bubble shown")
    assert(sameColor(minimap.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "idle back bubble is the circle's gray")
    assert(not sameColor(minimap.accentGlyph.vertexColor, Desaturation.DESAT_GREY), "not the square look's gray")
  end)

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
