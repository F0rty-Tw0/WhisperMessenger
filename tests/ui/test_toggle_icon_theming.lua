local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

local FRONT_GLYPH = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_front.png"
local BACK_GLYPH = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_back.png"

local function colorsMatch(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  local function round(n)
    return math.floor((n or 0) * 1000 + 0.5)
  end
  return round(a[1]) == round(b[1]) and round(a[2]) == round(b[2]) and round(a[3]) == round(b[3]) and round(a[4] or 1) == round(b[4] or 1)
end

local function regionsWithTexture(frame, path)
  local found = {}
  for _, child in ipairs(frame.children or {}) do
    if child.texturePath == path then
      found[#found + 1] = child
    end
  end
  return found
end

return function()
  local previousPreset = Theme.GetPreset()

  -- -----------------------------------------------------------------------
  -- Icon exposes a refreshTheme() function so the preset-switch flow can
  -- repaint the circle and bubbles without a /reload.
  -- -----------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})
    assert(type(icon.refreshTheme) == "function", "toggle_icon_refresh: should expose a refreshTheme function")
  end

  -- -----------------------------------------------------------------------
  -- The widget is a themed disc with two chat bubbles: a white front bubble
  -- and a back bubble in toggle_icon_glyph_back. No ring around it.
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})

    assert(icon.label.texturePath == FRONT_GLYPH, "bubbles_icon: front bubble art, got: " .. tostring(icon.label.texturePath))
    assert(icon.accentGlyph.texturePath == BACK_GLYPH, "bubbles_icon: back bubble art")
    assert(icon.accentGlyph.allPoints == icon.label, "bubbles_icon: back bubble sits with the front bubble")
    assert(colorsMatch(icon.accentGlyph.vertexColor, Theme.COLORS.toggle_icon_glyph_back), "bubbles_icon: back bubble in toggle_icon_glyph_back")
    assert(colorsMatch(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "bubbles_icon: bg should be tinted with toggle_icon_bg role")
    assert(colorsMatch(icon.label.vertexColor, Theme.COLORS.toggle_icon_glyph), "bubbles_icon: glyph should be tinted with toggle_icon_glyph role")
    assert(icon.border == nil, "bubbles_icon: no ring")
    assert(#regionsWithTexture(icon.frame, "Interface\\COMMON\\RingBorder") == 0, "bubbles_icon: no RingBorder texture")
  end

  -- -----------------------------------------------------------------------
  -- refreshTheme repaints the back bubble live when the preset changes.
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})
    local before = icon.accentGlyph.vertexColor

    Theme.SetPreset("elvui_dark")
    icon.refreshTheme()

    assert(colorsMatch(icon.accentGlyph.vertexColor, Theme.COLORS.toggle_icon_glyph_back), "refresh_icon: back bubble follows the new preset")
    assert(not colorsMatch(icon.accentGlyph.vertexColor, before), "refresh_icon: back bubble differs between wow_default and elvui_dark")
  end

  -- -----------------------------------------------------------------------
  -- Idle desaturation grays both bubbles; an unread whisper brings the
  -- colors back.
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(icon.accentGlyph.desaturated == true, "desat_icon: back bubble desaturated")
    assert(not colorsMatch(icon.accentGlyph.vertexColor, Theme.COLORS.toggle_icon_glyph_back), "desat_icon: back bubble gray")
    assert(icon.label.desaturated == true, "desat_icon: front bubble desaturated")
    icon.setUnreadCount(1)
    assert(icon.accentGlyph.desaturated == false, "desat_icon: back bubble in color with unread")
    assert(colorsMatch(icon.accentGlyph.vertexColor, Theme.COLORS.toggle_icon_glyph_back), "desat_icon: back bubble colored with unread")
  end

  -- -----------------------------------------------------------------------
  -- Hover lights both bubbles soft white, so the back bubble still reads
  -- when the hover fill matches its color (Jade Dark).
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("jade_dark")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})
    icon.frame:GetScript("OnEnter")(icon.frame)
    assert(colorsMatch(icon.accentGlyph.vertexColor, { 1, 1, 1, 0.45 }), "hover_icon: back bubble soft white on hover")
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(colorsMatch(icon.accentGlyph.vertexColor, Theme.COLORS.toggle_icon_glyph_back), "hover_icon: back bubble color back after hover")
  end

  if previousPreset then
    Theme.SetPreset(previousPreset)
  end

  print("  All toggle icon theming tests passed")
end
