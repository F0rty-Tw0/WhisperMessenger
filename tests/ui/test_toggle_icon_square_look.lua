-- The EllesmereUI preset draws the widget as a flat square with a 1px black
-- edge and the ring-free glyph; every other preset keeps the round look.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Bridge = require("WhisperMessenger.UI.Theme.EllesmereBridge")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

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

return function()
  -- test_ellesmere_preset_draws_a_square_widget
  withEllesmere(function()
    Theme.SetPreset("ellesmere_ui")
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, "square fill, got " .. tostring(icon.background.texturePath))
    assert(icon.label.texturePath == SquareLook.GLYPH_TEXTURE, "ring-free glyph, got " .. tostring(icon.label.texturePath))
    assert(icon.border.shown == false, "no ring")
    assert(edgesShown(icon.squareEdges, true), "1px edge shown")
    assert(icon.squareEdges.top.color[1] == 0 and icon.squareEdges.top.color[4] == 1, "edge is solid black")
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
