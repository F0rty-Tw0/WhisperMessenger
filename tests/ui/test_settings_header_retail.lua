-- Under the Retail Native WoW HUD a settings page title sits centred on the
-- ornate section banner from the character window's stats pane. The banner
-- replaces the divider line; the hint stays below in the secondary colour.
local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local PatchNotesSettings = require("WhisperMessenger.UI.MessengerWindow.PatchNotesSettings")

local BANNER_ATLAS = "UI-Character-Info-Title"
local TITLE_FONT = "GameFontNormalLarge"

local function colorsMatch(a, b)
  return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function lastPoint(region, anchor)
  local found
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      found = pt
    end
  end
  return found
end

local function newFrame()
  local factory = FakeUI.NewFactory()
  return factory.CreateFrame("Frame", nil, nil), factory
end

local function build(frame)
  frame = frame or newFrame()
  local header
  RetailHud.With(function()
    header = SettingsControls.CreateHeader(frame, { title = "Apparence", hint = "Hint text" })
  end)
  return header, frame
end

local function textures(frame)
  local found = {}
  for _, child in ipairs(frame.children or {}) do
    if child.frameType == "Texture" then
      found[#found + 1] = child
    end
  end
  return found
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")
  local padding = Theme.CONTENT_PADDING

  -- test_retail_title_sits_on_the_character_info_banner
  do
    local header, frame = build()
    local banner = header.banner
    assert(banner and banner.atlas == BANNER_ATLAS, "Retail: banner draws the character-info title atlas")
    assert(banner.useAtlasSize == false, "Retail: banner stretches instead of using the atlas size")
    local tl = lastPoint(banner, "TOPLEFT")
    assert(tl and tl[2] == frame and tl[4] == padding and tl[5] == -padding, "Retail: banner at the top-left padding")
    assert(banner.width == Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, "Retail: banner spans the control band")
    assert(banner.height and banner.height > 0, "Retail: banner has a height")
  end

  -- test_retail_title_is_centred_on_the_banner_in_the_title_colour
  do
    local header = build()
    local centre = lastPoint(header.title, "CENTER")
    assert(centre and centre[2] == header.banner, "Retail: title centred on the banner")
    assert(header.title.text == "Apparence", "Retail: title text kept")
    assert(header.title.fontObject == (_G[TITLE_FONT] or TITLE_FONT), "Retail: GameFontNormalLarge title")
    assert(colorsMatch(header.title.textColor, Theme.COLORS.text_title), "Retail: preset title colour")
  end

  -- test_retail_banner_replaces_the_divider
  do
    local header, frame = build()
    assert(header.leftLine == nil and header.rightLine == nil, "Retail: no divider halves")
    assert(#textures(frame) == 1, "Retail: the banner is the only texture")
  end

  -- test_retail_hint_sits_under_the_banner_in_secondary_colour
  do
    local header = build()
    assert(header.hint.text == "Hint text", "Retail: hint kept")
    assert(lastPoint(header.hint, "TOPLEFT")[2] == header.banner, "Retail: hint under the banner")
    assert(colorsMatch(header.hint.textColor, Theme.COLORS.text_secondary), "Retail: hint in secondary colour")
  end

  -- test_retail_theme_refresh_recolours_the_title
  do
    local header = build()
    Theme.SetPreset("wow_native")
    header.refreshTheme(Theme)
    assert(colorsMatch(header.title.textColor, Theme.COLORS.text_title), "Retail refresh: new title colour")
    assert(colorsMatch(header.hint.textColor, Theme.COLORS.text_secondary), "Retail refresh: new hint colour")
    Theme.SetPreset("wow_default")
  end

  -- test_retail_refresh_layout_resizes_the_banner
  do
    local header = build()
    header.refreshLayout(300)
    assert(header.banner.width == 300, "Retail: banner follows the panel width")
    assert(header.hint.width == 300, "Retail: hint follows the panel width")
  end

  -- test_retail_without_set_atlas_falls_back_to_the_classic_header
  do
    local frame = RetailHud.WithoutAtlas(newFrame())
    local header = build(frame)
    assert(header.banner == nil, "fallback: no banner")
    assert(header.leftLine ~= nil and lastPoint(header.leftLine, "TOPLEFT")[2] == header.title, "fallback: Classic divider under the title")
    assert(lastPoint(header.title, "TOPLEFT")[2] == frame, "fallback: Classic left-aligned title")
  end

  -- test_retail_whats_new_page_header_uses_the_banner
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    local page
    RetailHud.With(function()
      page = PatchNotesSettings.Create(factory, parent, { version = "2.0.0", lines = { "Fixed: a thing." } })
    end)
    local banner
    for _, child in ipairs(page.frame.children or {}) do
      if child.atlas == BANNER_ATLAS then
        banner = child
      end
    end
    assert(banner ~= nil, "What's New: page header on the banner")
    page.refreshLayout(400)
    assert(banner.width == 400, "What's New: banner follows the pane width")
  end

  Theme.SetPreset(previousPreset)
end
