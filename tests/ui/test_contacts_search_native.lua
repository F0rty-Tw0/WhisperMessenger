local FakeUI = require("tests.helpers.fake_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local ContactsSearchUI = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSearchUI")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")

local function buildSearch(factory, nativeChrome)
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(260, 500)
  return ContactsSearchUI.Build(factory, pane, {
    contactsWidth = 260,
    searchMargin = 10,
    searchHeight = 30,
    searchClearButtonSize = 18,
    nativeChrome = nativeChrome,
  })
end

local function buildLayout(useNativeChrome)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = useNativeChrome })
  return LayoutBuilder.Build(factory, chrome.frame, { width = 920, height = 580 }, {})
end

return function()
  -- test_hud_search_uses_search_box_template
  do
    local search = buildSearch(FakeUI.NewFactory(), true)
    assert(
      search.input.template == "SearchBoxTemplate",
      "HUD: search input should inherit SearchBoxTemplate, got " .. tostring(search.input.template)
    )
    assert(search.native == true, "HUD: search should report the native variant")
    assert(search.roundedBg == nil, "HUD: no custom rounded fill")
  end

  -- test_hud_search_reuses_template_instructions_and_clear_button
  do
    local search = buildSearch(FakeUI.NewFactory(), true)
    assert(search.placeholder == search.input.Instructions, "HUD: placeholder should be the template's Instructions text")
    assert(search.placeholder.text == "Search chats", "HUD: Instructions should carry the localized placeholder")
    assert(search.clearButton == search.input.clearButton, "HUD: clear button should be the template's clear button")
  end

  -- test_hud_search_without_template_children_still_builds
  do
    local factory = TemplateFactory.stripped(FakeUI.NewFactory(), "SearchBoxTemplate", { "Instructions", "clearButton", "searchIcon" })
    local search = buildSearch(factory, true)
    assert(search.input.template == "SearchBoxTemplate", "HUD: still the template input")
    assert(search.placeholder ~= nil and search.placeholder.text == "Search chats", "HUD: own placeholder when Instructions is missing")
    assert(search.clearButton == nil, "HUD: no clear button when the template has none")
    search.setLanguage()
  end

  -- test_hud_search_falls_back_to_modern_when_template_missing
  do
    local factory = TemplateFactory.missing(FakeUI.NewFactory(), "SearchBoxTemplate")
    local search = buildSearch(factory, true)
    assert(search.native ~= true, "fallback: modern search when the template is missing")
    assert(search.input.template == nil, "fallback: plain EditBox")
    assert(search.roundedBg ~= nil, "fallback: modern rounded fill")
  end

  -- test_modern_search_unchanged
  do
    local search = buildSearch(FakeUI.NewFactory(), false)
    assert(search.native ~= true, "modern: not native")
    assert(search.input.template == nil, "modern: plain EditBox, no template")
    assert(search.roundedBg ~= nil and search.icon ~= nil, "modern: rounded fill + magnifier stay")
    assert(search.clearLabel ~= nil and search.clearLabel.text == "X", "modern: X clear label stays")
    local tl = search.input.points[1]
    assert(tl[1] == "TOPLEFT" and tl[4] == 22 and tl[5] == -4, "modern: input inset unchanged")
  end

  -- test_hud_layout_builds_native_search_and_theme_leaves_it_alone
  do
    local layout = buildLayout(true)
    assert(layout.contactsSearchInput.template == "SearchBoxTemplate", "HUD layout: native search input")
    layout.contactsSearchPlaceholder.textColor = nil
    layout.contactsSearchInput.textColor = nil
    layout.applyTheme(Theme)
    assert(layout.contactsSearchPlaceholder.textColor == nil, "HUD: theme must not repaint the template placeholder")
    assert(layout.contactsSearchInput.textColor == nil, "HUD: theme must not repaint the template input text")
  end

  -- test_modern_layout_theme_still_paints_search
  do
    local layout = buildLayout(false)
    assert(layout.contactsSearchInput.template == nil, "modern layout: plain search input")
    layout.contactsSearchPlaceholder.textColor = nil
    layout.applyTheme(Theme)
    assert(layout.contactsSearchPlaceholder.textColor ~= nil, "modern: theme still paints the placeholder")
  end
end
