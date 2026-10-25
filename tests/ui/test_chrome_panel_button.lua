local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local BELL = "Interface\\Icons\\INV_Misc_Bell_01"

local function build(useNativeChrome, factory)
  factory = factory or FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = useNativeChrome })
end

local function withTooltip(fn)
  local saved = rawget(_G, "GameTooltip")
  local captured = {}
  rawset(_G, "GameTooltip", {
    SetOwner = function() end,
    SetText = function(_, text)
      captured.text = text
    end,
    Show = function() end,
    Hide = function() end,
  })
  local ok, err = pcall(fn, captured)
  rawset(_G, "GameTooltip", saved)
  assert(ok, err)
end

local function runStyle(label, useNativeChrome)
  local chrome = build(useNativeChrome)
  local clicked
  local first = chrome.addPanelButton("ca", { title = "Alerts", icon = BELL }, function(key)
    clicked = key
  end)
  local second = chrome.addPanelButton("two", { title = "Other", icon = 134400 })

  -- test_first_panel_button_follows_mark_all_read
  local point, rel, relPoint = first.button:GetPoint()
  assert(point == "LEFT" and rel == chrome.markAllReadButton and relPoint == "RIGHT", label .. ": first panel button right of mark-all-read")

  -- test_next_panel_button_follows_the_previous
  local _, rel2 = second.button:GetPoint()
  assert(rel2 == first.button, label .. ": second panel button right of the first")

  -- test_panel_button_matches_the_other_title_buttons
  assert(first.button.width ~= nil and first.button.width == chrome.markAllReadButton.width, label .. ": same size as mark-all-read")

  -- test_glyph_is_the_given_texture
  assert(first.icon.texturePath == BELL, label .. ": glyph is the caller's icon")
  assert(second.icon.texturePath == 134400, label .. ": file id icon accepted")

  -- test_tooltip_shows_the_title
  withTooltip(function(captured)
    first.button:GetScript("OnEnter")(first.button)
    assert(captured.text == "Alerts", label .. ": tooltip shows the caller title, got " .. tostring(captured.text))
  end)

  -- test_click_passes_the_key
  first.button:GetScript("OnClick")(first.button)
  assert(clicked == "ca", label .. ": click passes the key")

  -- test_click_without_handler_is_harmless
  second.button:GetScript("OnClick")(second.button)

  -- test_badge
  first.setBadge(3)
  assert(first.badge.text == "3" and first.badge:IsShown(), label .. ": badge shows 3")
  first.setBadge(0)
  assert(not first.badge:IsShown(), label .. ": zero hides the badge")
  first.setBadge(150)
  assert(first.badge.text == "99+" and first.badge:IsShown(), label .. ": badge caps at 99+")
  first.setBadge(-2)
  assert(not first.badge:IsShown(), label .. ": negative hides the badge")
  first.setBadge("x")
  assert(not first.badge:IsShown(), label .. ": non-number hides the badge")

  -- test_set_back_visible
  chrome.setBackVisible(true)
  assert(chrome.backButton:IsShown(), label .. ": setBackVisible(true) shows Back")
  chrome.setOptionsActive(false)
  assert(not chrome.backButton:IsShown(), label .. ": setOptionsActive(false) hides Back again")
  chrome.setBackVisible(true)
  chrome.setBackVisible(false)
  assert(not chrome.backButton:IsShown(), label .. ": setBackVisible(false) hides Back")
end

return function()
  runStyle("modern", false)
  runStyle("classic", true)
  RetailHud.With(function()
    runStyle("retail", true)
  end)

  -- test_retail_panel_button_draws_above_the_template_art
  RetailHud.With(function()
    local factory = RetailHud.Factory(FakeUI, {
      decorate = function(frame, template)
        if template == "ButtonFrameTemplate" and frame.CloseButton then
          frame.CloseButton:SetFrameLevel(510)
        end
      end,
    })
    local chrome = build(true, factory)
    local first = chrome.addPanelButton("ca", { title = "Alerts", icon = BELL })
    assert(first.button:GetFrameLevel() >= chrome.closeButton:GetFrameLevel(), "retail: panel button above the template art")
  end)

  -- test_modern_panel_button_draws_above_the_title_bar
  do
    local chrome = build(false)
    local first = chrome.addPanelButton("ca", { title = "Alerts", icon = BELL })
    assert(first.button:GetFrameLevel() > chrome.titleBar:GetFrameLevel(), "modern: panel button above the title bar")
  end
end
