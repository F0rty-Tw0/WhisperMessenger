-- The minimap button keeps its own disc and border and shows the two chat
-- bubbles inside them (back bubble in the accent), not the whole addon logo
-- with its second ring.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")

local FRONT_GLYPH = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_front.png"
local BACK_GLYPH = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_back.png"

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_minimap_shows_the_bubbles_inside_its_border
  do
    Theme.SetPreset("wow_default")
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {})
    local frameWidth = minimap.frame:GetWidth()
    assert(minimap.iconTex.texturePath == FRONT_GLYPH, "front bubble, got " .. tostring(minimap.iconTex.texturePath))
    assert(minimap.iconTex.width < frameWidth, "bubbles sit inside the border")
    assert(minimap.accentGlyph.texturePath == BACK_GLYPH and minimap.accentGlyph.allPoints == minimap.iconTex, "back bubble with it")
    assert(sameColor(minimap.accentGlyph.vertexColor, Theme.COLORS.accent), "back bubble in the accent")
    assert(minimap.border.texturePath == "Interface\\COMMON\\RingBorder", "minimap keeps its border")
  end

  -- test_minimap_accent_follows_the_preset
  do
    Theme.SetPreset("wow_default")
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {})
    Theme.SetPreset("wow_native")
    minimap.refreshTheme()
    assert(sameColor(minimap.accentGlyph.vertexColor, Theme.COLORS.accent), "accent after a preset switch")
  end

  -- test_minimap_back_bubble_grays_when_idle
  do
    Theme.SetPreset("wow_default")
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {
      getIconDesaturated = function()
        return true
      end,
    })
    minimap.setUnreadCount(0)
    assert(minimap.accentGlyph.desaturated == true, "gray when idle")
    minimap.setUnreadCount(2)
    assert(sameColor(minimap.accentGlyph.vertexColor, Theme.COLORS.accent), "accent with unread")
  end

  if previousPreset then
    Theme.SetPreset(previousPreset)
  end
end
