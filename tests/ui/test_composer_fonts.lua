local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer.Composer")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  Fonts.Initialize("default")

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 52)

  local selectedContact = {
    conversationKey = "me::WOW::test-realm",
    displayName = "Test-Realm",
    channel = "WOW",
  }

  local composer = Composer.Create(factory, parent, selectedContact, function() end, function() end)

  local expectedFont = _G[Theme.FONTS.composer_input]
  assert(expectedFont ~= nil, "expected WM_ChatNormal font object to exist")

  -- The placeholder should have fontObject set via SetFontObject
  local placeholder = composer.placeholder

  assert(placeholder ~= nil, "expected placeholder FontString to exist")
  assert(placeholder.fontObject == expectedFont, "expected placeholder fontObject to be WM_ChatNormal, got: " .. tostring(placeholder.fontObject))

  -- Composer text should localize when Russian is configured.
  Localization.Configure({ language = "ruRU" })
  local localizedComposer = Composer.Create(factory, parent, selectedContact, function() end, function() end)
  assert(localizedComposer.placeholder.text == "Enter для отправки", "expected localized composer placeholder")
  Localization.Configure({ language = "enUS" })
  -- The input EditBox should also have fontObject set
  local input = composer.input
  assert(input.fontObject == expectedFont, "expected input fontObject to be WM_ChatNormal, got: " .. tostring(input.fontObject))
end
