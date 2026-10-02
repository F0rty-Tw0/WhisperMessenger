local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Localization = require("WhisperMessenger.Locale.Localization")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local ADDON_ICON = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png"

local function build(factory)
  factory = factory or FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = true })
end

-- A factory whose ButtonFrameTemplate frames carry the live mixin helpers.
local function factoryWithHelpers(calls)
  return RetailHud.Factory(FakeUI, {
    decorate = function(frame, template)
      if template == "ButtonFrameTemplate" then
        function frame:SetTitle(text)
          calls.title = text
        end
        function frame:SetPortraitToAsset(path)
          calls.portrait = path
        end
      end
    end,
  })
end

local function withTooltip(fn)
  local saved = _G.GameTooltip
  local state = {}
  _G.GameTooltip = {
    SetOwner = function(_, owner)
      state.owner = owner
    end,
    SetText = function(_, text)
      state.text = text
    end,
    Show = function()
      state.shown = true
    end,
    Hide = function()
      state.hidden = true
    end,
  }
  local ok, err = pcall(fn, state)
  _G.GameTooltip = saved
  if not ok then
    error(err, 0)
  end
end

return function()
  local L = Theme.LAYOUT

  -- test_retail_window_is_built_from_button_frame_template
  RetailHud.With(function()
    local chrome = build()
    assert(chrome.frame.template == "ButtonFrameTemplate", "retail: expected ButtonFrameTemplate, got " .. tostring(chrome.frame.template))
    assert(chrome.closeButton == chrome.frame.CloseButton, "retail: close button is the template's")
    assert(chrome.background == chrome.frame.Bg, "retail: background is the template's")
  end)

  -- test_retail_title_and_portrait_use_the_template_helpers
  RetailHud.With(function()
    local calls = {}
    build(factoryWithHelpers(calls))
    assert(calls.title == Theme.MODERN_TITLE, "retail: SetTitle gets the addon name, got " .. tostring(calls.title))
    assert(calls.portrait == ADDON_ICON, "retail: SetPortraitToAsset gets the addon icon, got " .. tostring(calls.portrait))
  end)

  -- test_retail_portrait_falls_back_to_the_portrait_texture
  RetailHud.With(function()
    local chrome = build()
    local portrait = chrome.frame.PortraitContainer.portrait
    assert(portrait.texturePath == ADDON_ICON, "retail: portrait texture is the addon icon, got " .. tostring(portrait.texturePath))
  end)

  -- test_retail_title_falls_back_to_the_title_container_text
  RetailHud.With(function()
    local factory = RetailHud.Factory(FakeUI, {
      decorate = function(frame, template)
        if template == "ButtonFrameTemplate" then
          frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString(nil, "OVERLAY")
        end
      end,
    })
    local chrome = build(factory)
    assert(chrome.frame.TitleContainer.TitleText.text == Theme.MODERN_TITLE, "retail: title text set without SetTitle")
    assert(chrome.title == chrome.frame.TitleContainer.TitleText, "retail: chrome.title is the template's title text")
  end)

  -- test_retail_hides_the_button_bar_when_the_helper_exists
  RetailHud.With(function()
    local saved = rawget(_G, "ButtonFrameTemplate_HideButtonBar")
    local hidden
    rawset(_G, "ButtonFrameTemplate_HideButtonBar", function(frame)
      hidden = frame
    end)
    local ok, err = pcall(build)
    rawset(_G, "ButtonFrameTemplate_HideButtonBar", saved)
    assert(ok, err)
    assert(hidden ~= nil and hidden.template == "ButtonFrameTemplate", "retail: button bar hidden on the window")
  end)

  -- test_retail_content_area_sits_inside_the_border_below_the_portrait
  RetailHud.With(function()
    local chrome = build()
    local area = chrome.frame.contentArea
    assert(area ~= nil and area.parent == chrome.frame, "retail: expected frame.contentArea on the window")
    assert(area ~= chrome.frame.Inset, "retail: content area is addon-owned, not the template Inset")
    local tl, br = area.points[1], area.points[2]
    assert(tl[1] == "TOPLEFT" and tl[4] == L.RETAIL_HUD_INSET_LEFT and tl[5] == -L.RETAIL_HUD_INSET_TOP, "retail: content area TOPLEFT")
    assert(br[1] == "BOTTOMRIGHT" and br[4] == -L.RETAIL_HUD_INSET_RIGHT and br[5] == L.RETAIL_HUD_INSET_BOTTOM, "retail: content area BOTTOMRIGHT")
  end)

  -- test_retail_adds_a_contacts_inset
  RetailHud.With(function()
    local chrome = build()
    local inset = chrome.frame.contactsInset
    assert(inset ~= nil and inset.template == "InsetFrameTemplate", "retail: contacts inset from InsetFrameTemplate")
    assert(chrome.frame.conversationInset == chrome.frame.Inset, "retail: the template Inset backs the conversation")
  end)

  -- test_retail_close_button_tooltip
  RetailHud.With(function()
    local chrome = build()
    withTooltip(function(state)
      Localization.Configure({ language = "enUS" })
      chrome.closeButton:GetScript("OnEnter")(chrome.closeButton)
      assert(state.text == "Close" and state.shown and state.owner == chrome.closeButton, "retail: close tooltip shows")
      chrome.closeButton:GetScript("OnLeave")(chrome.closeButton)
      assert(state.hidden, "retail: close tooltip hides")
    end)
    Localization.Configure({ language = "auto" })
  end)

  -- test_retail_without_button_frame_template_builds_classic_chrome
  RetailHud.With(function()
    local chrome = build(RetailHud.Factory(FakeUI, { missing = { ButtonFrameTemplate = true } }))
    assert(chrome.frame.template == "BasicFrameTemplateWithInset", "fallback: classic template, got " .. tostring(chrome.frame.template))
    assert(Hud.Style() == "classic", "fallback: the session drops to the classic HUD so metrics match the frame")
    local tl = chrome.frame.contentArea.points[1]
    assert(tl[4] == L.HUD_INSET_LEFT + L.HUD_CONTENT_INSET, "fallback: classic content area")
  end)

  -- test_retail_without_inset_children_builds_without_error
  RetailHud.With(function()
    local factory = RetailHud.Factory(FakeUI, {
      missing = { InsetFrameTemplate = true },
      decorate = function(frame, template)
        if template == "ButtonFrameTemplate" then
          frame.Inset = nil
          frame.PortraitContainer = nil
        end
      end,
    })
    local chrome = build(factory)
    assert(chrome.frame.contentArea ~= nil, "no insets: content area still built")
    assert(chrome.frame.contactsInset == nil and chrome.frame.conversationInset == nil, "no insets: none recorded")
  end)
end
