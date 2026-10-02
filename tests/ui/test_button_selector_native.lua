-- Under the Native WoW HUD each selector option is a Blizzard panel button:
-- the chosen one keeps its highlight locked on, labels keep the preset's
-- colours, and none of the modern fills or the accent underline exist.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local ButtonSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

local TEMPLATE = "UIPanelButtonTemplate"

local function options(retailReason)
  return {
    { key = "off", label = "Off", tooltip = "Off tip" },
    { key = "classic", label = "Classic", tooltip = "Classic tip" },
    { key = "retail", label = "Retail", tooltip = "Retail tip", disabled = true, disabledReason = retailReason },
  }
end

local function build(factory)
  factory = factory or FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  Hud.Configure("classic")
  local selector = ButtonSelector.Create(factory, parent, {
    labelText = "Native WoW HUD",
    optionsList = options("Not on this client."),
    fallbackKey = "off",
    initial = "off",
    onChange = function(key)
      changes[#changes + 1] = key
    end,
  })
  Hud.Configure("off")
  return selector, changes
end

local function colorsMatch(a, b)
  return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function labelOf(btn)
  return btn.label
end

local function lockedKeys(selector)
  local out = {}
  for _, btn in ipairs(selector.buttons) do
    if btn.highlightLocked then
      out[#out + 1] = btn._key
    end
  end
  return table.concat(out, ",")
end

local function withTooltip(fn)
  local saved = rawget(_G, "GameTooltip")
  local tip = {}
  rawset(_G, "GameTooltip", {
    SetOwner = function() end,
    SetText = function(_self, text)
      tip.text = text
    end,
    Show = function() end,
    Hide = function() end,
  })
  local ok, err = pcall(fn, tip)
  rawset(_G, "GameTooltip", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_hud_options_are_panel_buttons
  do
    local selector = build()
    for _, btn in ipairs(selector.buttons) do
      assert(btn.template == TEMPLATE, "HUD option uses " .. TEMPLATE .. ", got " .. tostring(btn.template))
    end
  end

  -- test_hud_selected_option_locks_its_highlight_only
  do
    local selector = build()
    assert(lockedKeys(selector) == "off", "only the selected option is locked, got " .. lockedKeys(selector))
  end

  -- test_hud_click_moves_the_highlight_and_fires_on_change
  do
    local selector, changes = build()
    FindUI.click(selector.buttons[2])
    assert(changes[1] == "classic", "onChange fires with the clicked key")
    assert(lockedKeys(selector) == "classic", "highlight follows the click, got " .. lockedKeys(selector))
  end

  -- test_hud_set_selected_moves_the_highlight
  do
    local selector = build()
    selector.setSelected("classic")
    assert(lockedKeys(selector) == "classic", "setSelected moves the highlight, got " .. lockedKeys(selector))
  end

  -- test_hud_labels_use_the_preset_option_colours
  do
    local selector = build()
    assert(colorsMatch(labelOf(selector.buttons[1]).textColor, Theme.COLORS.option_button_text_active), "selected label: active colour")
    assert(colorsMatch(labelOf(selector.buttons[2]).textColor, Theme.COLORS.option_button_text), "other label: option colour")
  end

  -- test_hud_has_no_flat_fill_or_accent_underline
  do
    local selector = build()
    for _, btn in ipairs(selector.buttons) do
      assert(btn.bg == nil, "HUD option has no flat background fill")
      assert(btn.underline == nil, "HUD option has no accent underline")
      assert(btn.hover == nil, "HUD option has no flat hover wash")
    end
  end

  -- test_hud_unavailable_option_ignores_clicks_and_explains_why
  withTooltip(function(tip)
    local selector, changes = build()
    FindUI.click(selector.buttons[3])
    assert(#changes == 0, "unavailable option fires nothing")
    assert(lockedKeys(selector) == "off", "unavailable option does not take the highlight")
    local cover = assert(FindUI.disabledCover(selector.buttons[3]), "unavailable option has a hover cover")
    cover:GetScript("OnEnter")(cover)
    assert(tip.text == "Not on this client.", "hover shows the reason, got " .. tostring(tip.text))
  end)

  -- test_hud_relabel_keeps_selection_and_availability
  withTooltip(function(tip)
    local selector = build()
    selector.setSelected("classic")
    local relabelled = options("Nicht hier.")
    relabelled[2].label = "Klassisch"
    selector.setOptionsList(relabelled)
    assert(labelOf(selector.buttons[2]).text == "Klassisch", "relabel updates the visible text")
    assert(lockedKeys(selector) == "classic", "relabel keeps the highlight, got " .. lockedKeys(selector))
    local cover = assert(FindUI.disabledCover(selector.buttons[3]), "relabel keeps the cover")
    cover:GetScript("OnEnter")(cover)
    assert(tip.text == "Nicht hier.", "relabelled reason shows, got " .. tostring(tip.text))
  end)

  -- test_hud_theme_refresh_keeps_the_native_look
  do
    local selector = build()
    selector.applyTheme(Theme)
    assert(lockedKeys(selector) == "off", "theme refresh keeps the highlight")
    assert(selector.buttons[1].bg == nil, "theme refresh adds no flat fill")
  end

  -- test_hud_label_is_owned_so_button_font_swaps_cannot_recolour_it
  do
    local selector = build()
    local btn = selector.buttons[2]
    assert(btn.label.parent == btn and btn.label.text == "Classic", "own label carries the text")
    assert(btn.text == nil, "template text stays empty")
    assert(btn.width > 0, "buttons still get a fitted width")
  end

  -- test_hud_without_template_falls_back_to_modern_buttons
  do
    local selector = build(TemplateFactory.missing(FakeUI.NewFactory(), TEMPLATE))
    assert(selector.buttons[1].template == nil, "fallback is the modern button")
    assert(selector.buttons[1].underline ~= nil, "fallback keeps the accent underline")
  end

  -- test_modern_options_are_not_templated
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local selector = ButtonSelector.Create(factory, parent, { labelText = "Mode", optionsList = options("x"), fallbackKey = "off", initial = "off" })
    assert(selector.buttons[1].template == nil, "modern option is not templated")
    assert(selector.buttons[1].underline ~= nil, "modern option keeps the underline")
  end
end
