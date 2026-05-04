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

  -- The send button label should have fontObject set via SetFontObject
  local sendButton = composer.sendButton
  local buttonLabel
  for _, child in ipairs(sendButton.children) do
    if child.frameType == "FontString" and child.text == "Send" then
      buttonLabel = child
      break
    end
  end

  assert(buttonLabel ~= nil, "expected send button to have a FontString label")

  local expectedFont = _G[Theme.FONTS.composer_input]
  assert(expectedFont ~= nil, "expected WM_ChatNormal font object to exist")
  assert(
    buttonLabel.fontObject == expectedFont,
    "expected send button label fontObject to be WM_ChatNormal, got: " .. tostring(buttonLabel.fontObject)
  )

  -- The placeholder should have fontObject set via SetFontObject
  local placeholder
  for _, child in ipairs(parent.children) do
    -- The pane is a child of parent; walk its children
    for _, grandchild in ipairs(child.children or {}) do
      if grandchild.frameType == "FontString" and grandchild.text == "Type a message and press Enter" then
        placeholder = grandchild
        break
      end
    end
    if placeholder then
      break
    end
  end

  -- Placeholder is on the pane (which is the first child frame of parent)
  if not placeholder then
    -- Search the composer pane directly
    local pane = composer.frame
    for _, child in ipairs(pane.children) do
      if child.frameType == "FontString" and child.text == "Type a message and press Enter" then
        placeholder = child
        break
      end
    end
  end

  assert(placeholder ~= nil, "expected placeholder FontString to exist")
  assert(placeholder.fontObject == expectedFont, "expected placeholder fontObject to be WM_ChatNormal, got: " .. tostring(placeholder.fontObject))

  -- Composer text should localize when Russian is configured.
  Localization.Configure({ language = "ruRU" })
  local localizedComposer = Composer.Create(factory, parent, selectedContact, function() end, function() end)
  assert(localizedComposer.sendButton.label.text == "Отпр.", "expected localized send button label")
  assert(localizedComposer.placeholder.text == "Введите сообщение и нажмите Enter", "expected localized composer placeholder")
  Localization.Configure({ language = "enUS" })
  -- The input EditBox should also have fontObject set
  local input = composer.input
  assert(input.fontObject == expectedFont, "expected input fontObject to be WM_ChatNormal, got: " .. tostring(input.fontObject))
end
