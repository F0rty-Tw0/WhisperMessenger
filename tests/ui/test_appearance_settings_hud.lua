-- Appearance page and the Native WoW HUD: the Off / Classic / Retail picker,
-- with every other row (colours included) left enabled: presets still apply.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Flavor = require("tests.helpers.flavor")
local Theme = require("WhisperMessenger.UI.Theme")
local Localization = require("WhisperMessenger.Locale.Localization")

local RETAIL_REASON = "Not available on this game version."
local ROWS = {
  "Theme Preset",
  "Chat Font Color",
  "Bubble Colors",
  "Native WoW HUD",
  "Window Scale",
  "Font Family",
  "Font Size",
  "Font Outline",
  "Window Opacity (Inactive)",
  "Window Opacity (Active)",
}

local function create(config, hudStyle)
  Hud.Configure(hudStyle or "off")
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = AppearanceSettings.Create(factory, parent, config or {}, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  Hud.Configure("off")
  return result, changes
end

local function hudButtons(result)
  return FindUI.selectorButtons(result.frame, "Native WoW HUD")
end

local function presetButton(result, label)
  for _, btn in ipairs(FindUI.selectorButtons(result.frame, "Theme Preset")) do
    if btn.label.text == label then
      return btn
    end
  end
  error("no preset button " .. label)
end

local function withTooltip(fn)
  local saved = rawget(_G, "GameTooltip")
  local tip = {}
  rawset(_G, "GameTooltip", {
    SetOwner = function() end,
    SetText = function(_self, text)
      tip.text = text
    end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
  })
  local ok, err = pcall(fn, tip)
  rawset(_G, "GameTooltip", saved)
  if not ok then
    error(err, 0)
  end
end

local function hoverText(tip, target)
  local cover = FindUI.disabledCover(target)
  assert(cover, "expected a disabled cover")
  cover:GetScript("OnEnter")(cover)
  return tip.text
end

local function withRetailTemplates(fn)
  local saved = rawget(_G, "C_XMLUtil")
  rawset(_G, "C_XMLUtil", {
    GetTemplateInfo = function()
      return {}
    end,
  })
  local ok, err = pcall(fn)
  rawset(_G, "C_XMLUtil", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_hud_selector_offers_off_classic_retail
  do
    local result = create({ hudStyle = "classic" })
    local buttons = hudButtons(result)
    assert(#buttons == 3, "three HUD styles, got " .. #buttons)
    assert(
      buttons[1].label.text == "Off" and buttons[2].label.text == "Classic" and buttons[3].label.text == "Modern",
      "Off / Classic / Modern labels"
    )
    assert(buttons[2]._selected == true, "saved hudStyle is selected")
    for _, btn in ipairs(buttons) do
      assert(type(btn._tooltipText) == "string" and btn._tooltipText ~= "", btn.label.text .. " has a tooltip")
    end
  end

  -- test_hud_selector_saves_the_style
  do
    local result, changes = create({ hudStyle = "off" })
    FindUI.click(hudButtons(result)[2])
    assert(changes.hudStyle == "classic", "picking Classic saves hudStyle, got " .. tostring(changes.hudStyle))
  end

  -- test_picking_a_hud_style_leaves_the_preset_until_reload
  for _, case in ipairs({ { 2, "classic" }, { 3, "retail" } }) do
    local index, style = case[1], case[2]
    withRetailTemplates(function()
      local result, changes = create({ hudStyle = "off", themePreset = "elvui_dark" })
      FindUI.click(hudButtons(result)[index])
      assert(changes.themePreset == nil, style .. ": preset waits for the reload, got " .. tostring(changes.themePreset))
      assert(presetButton(result, "Azeroth")._selected ~= true, style .. ": Azeroth is not selected yet")
    end)
  end

  -- test_missing_hud_style_shows_off
  do
    local result = create({})
    assert(hudButtons(result)[1]._selected == true, "no saved style shows Off")
  end

  -- test_reset_picks_modern_on_retail
  Flavor.With(true, false, function()
    local result, changes = create({ hudStyle = "classic" })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.hudStyle == "retail", "reset sets hudStyle Modern on Retail, got " .. tostring(changes.hudStyle))
  end)

  -- test_reset_turns_the_hud_off_on_classic
  Flavor.With(false, false, function()
    local result, changes = create({ hudStyle = "classic" })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.hudStyle == "off", "reset sets hudStyle off on Classic flavors, got " .. tostring(changes.hudStyle))
  end)

  -- test_retail_is_unavailable_without_its_templates
  withTooltip(function(tip)
    local result, changes = create({ hudStyle = "off" })
    local retail = hudButtons(result)[3]
    assert(retail:GetAlpha() == 0.4, "Retail is dimmed when the game lacks its templates")
    FindUI.click(retail)
    assert(changes.hudStyle == nil, "unavailable Retail cannot be picked")
    assert(hoverText(tip, retail) == RETAIL_REASON, "Retail explains why it is unavailable")
  end)

  -- test_retail_is_available_with_its_templates
  withRetailTemplates(function()
    local result, changes = create({ hudStyle = "off" })
    local retail = hudButtons(result)[3]
    assert(retail:GetAlpha() == 1, "Retail is not dimmed when available")
    FindUI.click(retail)
    assert(changes.hudStyle == "retail", "available Retail can be picked")
  end)

  -- test_every_row_stays_enabled_with_or_without_hud
  for _, style in ipairs({ "classic", "off" }) do
    local result = create({}, style)
    for _, label in ipairs(ROWS) do
      local row = FindUI.byLabel(result.frame, label)
      assert(row:GetAlpha() == 1 and FindUI.disabledCover(row) == nil, label .. " stays enabled (" .. style .. ")")
    end
  end
end
