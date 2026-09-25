local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local HeaderElements = require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane.ConversationPane")

local function build(factory, nativeChrome)
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)
  local container = HeaderElements.createEmptyState(pane, nil, factory, nativeChrome)
  return container, FindUI.ofType(container, "Button")[1]
end

return function()
  -- test_hud_empty_state_button_uses_ui_panel_button_template
  do
    local _, button = build(FakeUI.NewFactory(), true)
    assert(button.template == "UIPanelButtonTemplate", "HUD: Start New Whisper should be a UIPanelButtonTemplate button")
    assert(button.text == "Start New Whisper", "HUD: label via the button's own SetText")
    assert(#FindUI.ofType(button, "Texture") == 0, "HUD: no custom fill or icon over the Blizzard art")
  end

  -- test_hud_empty_state_button_opens_new_whisper_popup
  do
    local shown = nil
    rawset(_G, "StaticPopup_Show", function(which)
      shown = which
    end)
    local _, button = build(FakeUI.NewFactory(), true)
    button.scripts.OnClick(button)
    assert(shown == "WHISPER_MESSENGER_START_CONVERSATION", "HUD: click still opens the new-whisper popup")
    rawset(_G, "StaticPopup_Show", nil)
  end

  -- test_hud_empty_state_theme_and_language_refresh
  do
    local container, button = build(FakeUI.NewFactory(), true)
    container.applyTheme()
    container.setLanguage()
    assert(button.text == "Start New Whisper", "HUD: setLanguage relabels the template button")
  end

  -- test_hud_empty_state_falls_back_when_template_missing
  do
    local factory = TemplateFactory.missing(FakeUI.NewFactory(), "UIPanelButtonTemplate")
    local _, button = build(factory, true)
    assert(button.template == nil, "fallback: modern button")
    assert(#FindUI.ofType(button, "Texture") == 2, "fallback: modern fill + icon")
  end

  -- test_modern_empty_state_button_unchanged
  do
    local container, button = build(FakeUI.NewFactory(), false)
    assert(button.template == nil, "modern: plain button")
    assert(button.width == 150 and button.height == 24, "modern: 150x24 unchanged")
    assert(#FindUI.ofType(button, "Texture") == 2, "modern: fill + icon kept")
    assert(FindUI.text(container, "Start New Whisper") ~= nil, "modern: own label")
  end

  -- test_conversation_pane_hud_builds_native_empty_button
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(600, 420)
    local view = ConversationPane.Create(factory, parent, nil, nil, { hideEmptyHeader = true, nativeChrome = true })
    local button = FindUI.ofType(view.headerEmpty, "Button")[1]
    assert(button.template == "UIPanelButtonTemplate", "HUD pane: native empty-state button")
  end
end
