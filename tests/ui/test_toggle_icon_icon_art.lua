local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_create_paints_round_face_and_glyph

  do
    local frame = factory.CreateFrame("Button", nil, parent)
    local art = IconArt.Create(frame, 40)

    assert(art.background.texturePath == IconArt.CIRCLE_TEX, "test_create_paints_round_face_and_glyph: background should use the circle texture")
    assert(art.chatIcon.texturePath == IconArt.ADDON_ICON_TEXTURE, "test_create_paints_round_face_and_glyph: glyph should use the addon icon")
    assert(
      art.chatIcon.width == 36,
      "test_create_paints_round_face_and_glyph: glyph should be 90% of the icon size, got " .. tostring(art.chatIcon.width)
    )
    assert(art.border.texturePath ~= nil, "test_create_paints_round_face_and_glyph: border should have a ring texture")
  end

  -- test_apply_size_floors_glyph_size

  do
    local frame = factory.CreateFrame("Button", nil, parent)
    local art = IconArt.Create(frame, 40)

    art.applySize(51)

    assert(art.chatIcon.width == 45, "test_apply_size_floors_glyph_size: 51 * 0.9 should floor to 45, got " .. tostring(art.chatIcon.width))
  end

  -- test_ring_color_falls_back_to_faded_accent

  do
    local savedRing = Theme.COLORS.toggle_icon_ring
    local savedAccent = Theme.COLORS.accent
    Theme.COLORS.toggle_icon_ring = nil
    Theme.COLORS.accent = { 0.2, 0.4, 0.6, 1 }

    local c = IconArt.ResolveRingColor()

    Theme.COLORS.toggle_icon_ring = savedRing
    Theme.COLORS.accent = savedAccent
    assert(c[1] == 0.2 and c[2] == 0.4 and c[3] == 0.6, "test_ring_color_falls_back_to_faded_accent: ring should take the accent hue")
    assert(c[4] == 0.3, "test_ring_color_falls_back_to_faded_accent: ring fallback alpha should be 0.3, got " .. tostring(c[4]))
  end
end
