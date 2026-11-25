local FakeUI = require("tests.helpers.fake_ui")
local BevelAtlas = require("tests.helpers.bevel_atlas")
local Theme = require("WhisperMessenger.UI.Theme")
local ScreenEdgeTabBand = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ScreenEdgeTabBand")

-- The darkened band the tab strip sits in at the bottom of a docked window.
local L = Theme.LAYOUT

local function build(hud)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "Window", nil)
  return ScreenEdgeTabBand.Create(factory, frame, { hud = hud }), frame
end

return function()
  -- test_band_spans_the_window_bottom_with_room_around_the_tabs
  do
    local band, frame = build(true)
    local height = band.show(32, 2)
    -- No atlas: a 1 px line; the strip's top tucks 2 px up under it.
    assert(height == 1 - 2 + 32 + L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM, "band height, got " .. tostring(height))
    assert(band.frame:IsShown() and band.frame.height == height, "shown at its height")
    local p1, p2 = band.frame.points[1], band.frame.points[2]
    assert(p1[1] == "BOTTOMLEFT" and p1[2] == frame and p1[4] == 0 and p1[5] == 0, "bottom-left of the window")
    assert(p2[1] == "BOTTOMRIGHT" and p2[2] == frame and p2[4] == 0 and p2[5] == 0, "bottom-right of the window")
    assert(band.fill.color[1] == 0 and band.fill.alpha == 0.5, "darkened by a half-black fill")
  end

  -- test_hud_band_has_the_inset_bevel_on_top_when_the_client_knows_it
  BevelAtlas.With(function()
    local band = build(true)
    local height = band.show(32, 2)
    local d = band.divider
    assert(d:IsShown() and d.height == 3, "3 px")
    -- The strip (its bottom PAD_BOTTOM up) hangs from the divider's bottom, overlap 2 px up.
    local stripTop = L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM + 32
    assert(stripTop == height - 3 + 2, "strip top flush under the bevel, band " .. tostring(height))
    assert(d.atlas == "_UI-Frame-InnerBotTile", "the inset bottom bevel, got " .. tostring(d.atlas))
    assert(d.color == nil, "no colour line painted over the bevel")
    assert(d.points[1][1] == "TOPLEFT" and d.points[1][2] == band.frame, "on the band's top")
  end)

  -- test_hud_band_falls_back_to_a_line_without_the_atlas
  do
    local band = build(true)
    band.show(32)
    local d = band.divider
    assert(d.atlas == nil and d.height == 1, "no atlas: a 1 px line")
    assert(d.color[1] == Theme.COLORS.window_border[1], "window border colour")
  end

  -- test_custom_band_has_a_1px_window_border_divider
  do
    local band = build(false)
    local height = band.show(24, 0)
    assert(L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM + 24 == height - 1, "custom strip top flush under the 1 px line, band " .. tostring(height))
    assert(band.divider.height == 1 and band.divider.color[1] == Theme.COLORS.window_border[1], "1 px window border")
  end

  -- test_hide_hides_the_band
  do
    local band = build(true)
    band.show(32)
    band.hide()
    assert(not band.frame:IsShown(), "hidden")
  end
end
