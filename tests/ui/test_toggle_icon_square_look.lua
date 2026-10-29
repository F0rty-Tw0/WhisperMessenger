-- The EllesmereUI preset draws the widget as a flat square with a 1px black
-- edge and the ring-free glyph; every other preset keeps the round look.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Bridge = require("WhisperMessenger.UI.Theme.EllesmereBridge")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local PulseGlow = require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local ButtonLook = require("WhisperMessenger.UI.Theme.EllesmereButtonLook")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local SLOT_BG = ButtonLook.Read().bg -- EllesmereUI's defaults: the fake has no action bars module
local ROUND_BG = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local ROUND_GLYPH = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png"

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

-- The round pulse art, stretched over the whole button.
local function fillsButton(texture)
  return texture.texturePath == PulseGlow.TEXTURE and texture.point == nil and texture.allPoints ~= nil
end

return function()
  -- test_ellesmere_preset_draws_a_square_widget
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "square fill, got " .. tostring(icon.background.texturePath))
    assert(icon.label.texturePath == SquareLook.GLYPH_TEXTURE, "ring-free glyph, got " .. tostring(icon.label.texturePath))
    assert(icon.border.shown == false, "no ring")
    assert(edgesShown(icon.squareEdges, true), "1px edge shown")
    assert(sameColor(icon.squareEdges.top.vertexColor, { 0, 0, 0, 1 }), "edge is solid black, like EllesmereUI's buttons")
    assert(sameColor(icon.background.vertexColor, SLOT_BG), "EllesmereUI's slot background")
    assert(icon.accentGlyph.shown == true, "accent back bubble shown")
    assert(icon.accentGlyph.texturePath == SquareLook.ACCENT_GLYPH_TEXTURE, "back bubble art")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "back bubble in the accent color")
  end)

  -- test_accent_bubble_grays_out_with_the_icon
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_GREY), "gray while desaturated")
    icon.setUnreadCount(2)
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "accent again with unread whispers")
  end)

  -- test_desaturating_leaves_the_white_bubble_and_background_alone
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
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
  end)

  -- test_round_look_still_desaturates_everything
  do
    Theme.SetPreset("wow_default")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(icon.label.desaturated == true, "round glyph still grays out")
  end

  -- test_background_option_hides_the_square
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local showBackground = false
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
      getIconBackground = function()
        return showBackground
      end,
    })
    assert(icon.background.shown == false, "no fill")
    assert(edgesShown(icon.squareEdges, false), "no edge")
    assert(icon.accentGlyph.shown == true and icon.label.texturePath == SquareLook.GLYPH_TEXTURE, "both bubbles still shown")
    showBackground = true
    icon.refreshTheme()
    assert(icon.background.shown == true and edgesShown(icon.squareEdges, true), "square back when turned on")
  end)

  -- test_hover_fills_only_the_back_bubble_with_the_accent
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
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
  end)

  -- test_square_shows_the_action_bar_hover_and_pushed_effects
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local showBackground = true
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
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
  end)

  -- test_hover_glows_in_the_accent_without_the_square
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
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
  end)

  -- test_outline_around_the_bubbles_only_without_the_square
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local showBackground = false
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
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
    Theme.SetPreset("wow_default")
    icon.refreshTheme()
    assert(outline.shown == false, "no outline on the round widget")
  end)

  -- test_unread_pulse_glows_around_the_bubbles
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local showBackground = false
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
      getIconBackground = function()
        return showBackground
      end,
    })
    assert(onBubbles(icon.pulseTexture, icon.label), "pulse follows the bubbles, got " .. tostring(icon.pulseTexture.texturePath))
    icon.applyIconSize(60)
    assert(onBubbles(icon.pulseTexture, icon.label), "pulse resized with the icon")
    showBackground = true
    icon.refreshTheme()
    assert(onBubbles(icon.pulseTexture, icon.label), "square shown: still around the bubbles")
    Theme.SetPreset("wow_default")
    icon.refreshTheme()
    assert(fillsButton(icon.pulseTexture, icon.frame), "round again on other presets")
  end)

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
    assert(icon.label.texturePath == ROUND_GLYPH, "original icon")
    assert(icon.border.shown == true, "ring shown")
    assert(edgesShown(icon.squareEdges, false), "no square edge")
    assert(icon.accentGlyph.shown == false, "no accent back bubble")
  end

  -- test_switching_presets_swaps_the_look_live
  withEllesmere(function()
    Theme.SetPreset("wow_default")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
    Theme.SetPreset("ellesmere_ui")
    icon.refreshTheme()
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "square after switching to EllesmereUI")
    assert(icon.border.shown == false and edgesShown(icon.squareEdges, true), "edge replaces ring")
    Theme.SetPreset("elvui_dark")
    icon.refreshTheme()
    assert(icon.background.texturePath == ROUND_BG and icon.label.texturePath == ROUND_GLYPH, "round again")
    assert(icon.border.shown == true and edgesShown(icon.squareEdges, false), "ring back, edge gone")
  end)

  -- test_minimap_button_uses_the_glyph_under_ellesmere
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {})
    assert(minimap.iconTex.texturePath == SquareLook.GLYPH_TEXTURE, "minimap glyph, got " .. tostring(minimap.iconTex.texturePath))
    assert(minimap.accentGlyph.shown == true and sameColor(minimap.accentGlyph.vertexColor, Theme.COLORS.accent), "minimap accent bubble")
    Theme.SetPreset("wow_default")
    minimap.refreshTheme()
    assert(minimap.iconTex.texturePath == ROUND_GLYPH, "original minimap icon on other presets")
    assert(minimap.accentGlyph.shown == false, "no accent bubble on other presets")
  end)

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
