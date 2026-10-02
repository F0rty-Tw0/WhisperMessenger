-- Under the Native WoW HUD the options menu and content backgrounds stay
-- clear so the window template's art shows through, like the contacts pane;
-- the theme's nav paint leaves Blizzard art on nav items alone.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ThemeApply = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ThemeApply")

local function buildLayout(useNativeChrome)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = useNativeChrome })
  return LayoutBuilder.Build(factory, chrome.frame, { width = 920, height = 580 }, {})
end

local function colorsMatch(a, b)
  return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

-- The texture filling `pane` (its background).
local function fillOf(pane)
  for _, child in ipairs(pane.children or {}) do
    if child.frameType == "Texture" and child.allPoints == pane then
      return child
    end
  end
  error("pane has no background fill")
end

local function isTransparent(texture)
  return texture.color ~= nil and texture.color[4] == 0
end

local function navTab(factory, nativeArt)
  local tab = factory.CreateFrame("Button", nil, nil)
  tab.bg = tab:CreateTexture(nil, "BACKGROUND")
  tab.bg._wmNativeArt = nativeArt
  tab.label = tab:CreateFontString(nil, "OVERLAY")
  return tab
end

return function()
  -- test_hud_options_backgrounds_are_transparent_when_built
  do
    local layout = buildLayout(true)
    assert(isTransparent(fillOf(layout.optionsMenu)), "HUD: options menu bg transparent on build")
    assert(isTransparent(fillOf(layout.optionsContentPane)), "HUD: options content bg transparent on build")
  end

  -- test_hud_options_backgrounds_stay_transparent_after_theme_apply
  do
    local layout = buildLayout(true)
    layout.applyTheme(Theme)
    assert(isTransparent(fillOf(layout.optionsMenu)), "HUD: options menu bg stays transparent")
    assert(isTransparent(fillOf(layout.optionsContentPane)), "HUD: options content bg stays transparent")
    assert(colorsMatch(layout.optionsMenuDivider.color, Theme.COLORS.divider), "HUD: menu/content divider keeps the preset hairline")
  end

  -- test_modern_options_backgrounds_keep_the_preset_fills
  do
    local layout = buildLayout(false)
    layout.applyTheme(Theme)
    assert(colorsMatch(fillOf(layout.optionsMenu).color, Theme.COLORS.bg_secondary), "modern: options menu bg")
    assert(colorsMatch(fillOf(layout.optionsContentPane).color, Theme.COLORS.bg_primary), "modern: options content bg")
  end

  -- test_nav_paint_skips_native_art
  do
    local factory = FakeUI.NewFactory()
    local nativeTab = navTab(factory, true)
    local flatTab = navTab(factory, nil)
    nativeTab._wmIsActiveTab = true
    local holder = factory.CreateFrame("Frame", nil, nil)
    ThemeApply.Create({
      nativeSearch = true,
      optionsHint = holder:CreateFontString(nil, "OVERLAY"),
      generalTab = nativeTab,
      appearanceTab = flatTab,
    }).applyTheme(Theme)
    assert(nativeTab.bg.color == nil, "native nav art is not overpainted")
    assert(colorsMatch(nativeTab.label.textColor, Theme.COLORS.option_button_text_active), "native nav label keeps the preset colour")
    assert(colorsMatch(flatTab.bg.color, Theme.COLORS.option_button_bg), "flat nav fill still painted")
  end
end
