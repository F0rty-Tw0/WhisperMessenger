local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

local function colorsMatch(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  local function round(n)
    return math.floor((n or 0) * 1000 + 0.5)
  end
  return round(a[1]) == round(b[1]) and round(a[2]) == round(b[2]) and round(a[3]) == round(b[3]) and round(a[4] or 1) == round(b[4] or 1)
end

return function()
  local previousPreset = Theme.GetPreset()

  -- -----------------------------------------------------------------------
  -- Icon exposes a refreshTheme() function so the preset-switch flow can
  -- repaint the circle and glyph without a /reload.
  -- -----------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})
    assert(type(icon.refreshTheme) == "function", "toggle_icon_refresh: should expose a refreshTheme function")
  end

  -- -----------------------------------------------------------------------
  -- Modern presets paint the icon with the existing Modern textures and
  -- themed color roles.
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})

    assert(icon.border == nil, "no ring")
    assert(colorsMatch(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "modern_icon: bg should be tinted with toggle_icon_bg role")
    assert(colorsMatch(icon.label.vertexColor, Theme.COLORS.toggle_icon_glyph), "modern_icon: glyph should be tinted with toggle_icon_glyph role")
  end

  -- -----------------------------------------------------------------------
  -- Azeroth (wow_native) paints the same face: theming is color-only.
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})

    assert(icon.border == nil, "azeroth_icon: no ring")
    assert(colorsMatch(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "azeroth_icon: bg should be tinted with toggle_icon_bg role")
    assert(colorsMatch(icon.label.vertexColor, Theme.COLORS.toggle_icon_glyph), "azeroth_icon: glyph should be tinted with toggle_icon_glyph role")
  end

  -- -----------------------------------------------------------------------
  -- refreshTheme repaints tints live when the preset changes.
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})

    local src = icon.background.vertexColor or {}
    local modernBgColor = { src[1], src[2], src[3], src[4] }

    Theme.SetPreset("wow_native")
    icon.refreshTheme()

    assert(
      colorsMatch(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg),
      "refresh_icon: bg tint should match wow_native toggle_icon_bg after refresh"
    )
    assert(not colorsMatch(icon.background.vertexColor, modernBgColor), "refresh_icon: bg tint should differ between wow_default and wow_native")
  end

  if previousPreset then
    Theme.SetPreset(previousPreset)
  end

  print("  All toggle icon theming tests passed")
end
