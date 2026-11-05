local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")

local function near(a, b)
  return math.abs(a - b) < 1e-9
end

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_create_paints_round_face_and_glyph

  do
    local frame = factory.CreateFrame("Button", nil, parent)
    local art = IconArt.Create(frame, 40)

    assert(art.background.texturePath == IconArt.CIRCLE_TEX, "test_create_paints_round_face_and_glyph: background should use the circle texture")
    assert(art.chatIcon.texturePath == SquareLook.GLYPH_TEXTURE, "test_create_paints_round_face_and_glyph: glyph should be the front bubble")
    assert(
      art.chatIcon.width == 36,
      "test_create_paints_round_face_and_glyph: glyph should be 90% of the icon size, got " .. tostring(art.chatIcon.width)
    )
    assert(IconArt.GLYPH_RATIO == 0.9, "test_create_paints_round_face_and_glyph: glyph ratio should be 0.9")
  end

  -- test_apply_size_floors_glyph_size

  do
    local frame = factory.CreateFrame("Button", nil, parent)
    local art = IconArt.Create(frame, 40)

    art.applySize(51)

    assert(art.chatIcon.width == 45, "test_apply_size_floors_glyph_size: 51 * 0.9 should floor to 45, got " .. tostring(art.chatIcon.width))
  end

  -- test_hover_bg_blends_accent_into_bg

  do
    local savedBg = Theme.COLORS.toggle_icon_bg
    local savedAccent = Theme.COLORS.accent
    Theme.COLORS.toggle_icon_bg = { 0.06, 0.18, 0.30, 1 }
    Theme.COLORS.accent = { 0.12, 0.72, 0.96, 1 }

    local c = IconArt.ResolveHoverBgColor()

    Theme.COLORS.toggle_icon_bg = savedBg
    Theme.COLORS.accent = savedAccent
    assert(near(c[1], 0.069) and near(c[2], 0.261) and near(c[3], 0.399), "test_hover_bg_blends_accent_into_bg: 85% bg + 15% accent")
    assert(c[4] == 1, "test_hover_bg_blends_accent_into_bg: alpha should follow bg")
  end

  -- test_hover_bg_alpha_follows_bg

  do
    local savedBg = Theme.COLORS.toggle_icon_bg
    local savedAccent = Theme.COLORS.accent
    Theme.COLORS.toggle_icon_bg = { 0.06, 0.18, 0.30, 0.5 }
    Theme.COLORS.accent = { 0.12, 0.72, 0.96, 1 }

    local c = IconArt.ResolveHoverBgColor()

    Theme.COLORS.toggle_icon_bg = savedBg
    Theme.COLORS.accent = savedAccent
    assert(c[4] == 0.5, "test_hover_bg_alpha_follows_bg: alpha should be 0.5, got " .. tostring(c[4]))
  end

  -- test_hover_bg_without_accent_is_plain_bg

  do
    local savedBg = Theme.COLORS.toggle_icon_bg
    local savedAccent = Theme.COLORS.accent
    Theme.COLORS.toggle_icon_bg = { 0.06, 0.18, 0.30, 1 }
    Theme.COLORS.accent = nil

    local c = IconArt.ResolveHoverBgColor()

    Theme.COLORS.toggle_icon_bg = savedBg
    Theme.COLORS.accent = savedAccent
    assert(c[1] == 0.06 and c[2] == 0.18 and c[3] == 0.30 and c[4] == 1, "test_hover_bg_without_accent_is_plain_bg: should fall back to bg")
  end

  -- test_paint_face_paints_the_circle_and_the_glyph

  do
    local frame = factory.CreateFrame("Button", nil, parent)
    local art = IconArt.Create(frame, 40)

    IconArt.PaintFace(art, true)
    assert(sameColor(art.background.vertexColor, IconArt.ResolveHoverBgColor()), "test_paint_face: hovered: the lift")
    assert(sameColor(art.chatIcon.vertexColor, Theme.COLORS.toggle_icon_glyph), "test_paint_face: hovered: glyph color")

    IconArt.PaintFace(art, false)
    assert(sameColor(art.background.vertexColor, Theme.COLORS.toggle_icon_bg), "test_paint_face: idle: the plain circle")
    assert(sameColor(art.chatIcon.vertexColor, Theme.COLORS.toggle_icon_glyph), "test_paint_face: idle: glyph color")
  end
end
