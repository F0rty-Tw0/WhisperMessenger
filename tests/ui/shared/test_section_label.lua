-- Sub-section labels inside a settings page ("Privacy", "Time Display",
-- "Quick replies"). Modern and Classic HUD: a small secondary-colour label.
-- Retail HUD: the label centred on a smaller character-info banner.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local GeneralSettings = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

local BANNER_ATLAS = "UI-Character-Info-Title"

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
  return FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
end

local function buildRetail(frame)
  frame = frame or newFrame()
  local section
  RetailHud.With(function()
    section = SettingsControls.CreateSectionLabel(frame, "Privacy")
  end)
  return section, frame
end

local function assertPlain(section, frame, context)
  assert(section.label.text == "Privacy", context .. ": text kept")
  assert(section.region == section.label, context .. ": controls anchor to the label")
  assert(section.label.template == Theme.FONTS.system_text, context .. ": small font")
  assert(colorsMatch(section.label.textColor, Theme.COLORS.text_secondary), context .. ": secondary colour")
  assert(#FindUI.ofType(frame, "Texture") == 0, context .. ": no banner")
end

local function assertOnBanner(root, labelText, context)
  local label = FindUI.text(root, labelText)
  assert(label, context .. ": label exists")
  local centre = lastPoint(label, "CENTER")
  assert(centre and centre[2].atlas == BANNER_ATLAS, context .. ": label centred on the banner")
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_modern_section_label_is_a_small_secondary_label
  do
    local frame = newFrame()
    assertPlain(SettingsControls.CreateSectionLabel(frame, "Privacy"), frame, "modern")
  end

  -- test_classic_hud_section_label_is_unchanged
  do
    local frame = newFrame()
    Hud.Configure("classic")
    local section = SettingsControls.CreateSectionLabel(frame, "Privacy")
    Hud.Configure("off")
    assertPlain(section, frame, "Classic HUD")
  end

  -- test_retail_section_label_sits_centred_on_a_banner
  do
    local section = buildRetail()
    local banner = section.region
    assert(banner.atlas == BANNER_ATLAS, "Retail: banner draws the character-info title atlas")
    assert(banner.useAtlasSize == false, "Retail: banner stretches")
    assert(banner.width == Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, "Retail: banner spans the control band")
    assert(lastPoint(section.label, "CENTER")[2] == banner, "Retail: label centred on the banner")
    assert(section.label.text == "Privacy", "Retail: text kept")
    assert(colorsMatch(section.label.textColor, Theme.COLORS.text_title), "Retail: preset title colour")
  end

  -- test_retail_section_banner_is_shorter_than_the_page_banner
  do
    local section, frame = buildRetail()
    local header
    RetailHud.With(function()
      header = SettingsControls.CreateHeader(frame, { title = "General", hint = "" })
    end)
    assert(section.region.height < header.banner.height, "Retail: section banner is the smaller one")
  end

  -- test_retail_section_label_follows_theme_and_width
  do
    local section = buildRetail()
    Theme.SetPreset("wow_native")
    section.refreshTheme(Theme)
    assert(colorsMatch(section.label.textColor, Theme.COLORS.text_title), "Retail refresh: new title colour")
    Theme.SetPreset("wow_default")
    section.refreshLayout(250)
    assert(section.region.width == 250, "Retail: banner follows the panel width")
  end

  -- test_retail_without_set_atlas_keeps_the_plain_label
  do
    local frame = RetailHud.WithoutAtlas(newFrame())
    local section = buildRetail(frame)
    assert(section.region == section.label, "fallback: controls anchor to the label")
    assert(colorsMatch(section.label.textColor, Theme.COLORS.text_secondary), "fallback: secondary colour")
  end

  -- test_retail_settings_pages_put_section_labels_on_banners
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    local general, behavior
    RetailHud.With(function()
      general = GeneralSettings.Create(factory, parent, {}, {})
      behavior = BehaviorSettings.Create(factory, parent, { quickReplies = {} }, {})
    end)
    assertOnBanner(general.frame, "Privacy", "General")
    assertOnBanner(general.frame, "Time Display", "General")
    assertOnBanner(behavior.frame, "Quick replies (0/10)", "Behavior")
  end

  Theme.SetPreset(previousPreset)
end
