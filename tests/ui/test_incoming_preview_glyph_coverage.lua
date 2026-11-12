local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Theme = require("WhisperMessenger.UI.Theme")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

-- The popup for a new whisper shows "ő" or "ű" in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  local preview = IncomingPreview.Create(factory, parent, {})

  -- test_sender_and_message_with_double_acute_letters_use_the_wide_font
  preview.setIncomingPreview("Kőszívű", "jössz, főnök?", nil)
  assert(preview.senderLabel:GetFontObject() == rawget(_G, "WM_Highlight_Wide"), "the sender needs the chat font")
  assert(preview.messageLabel:GetFontObject() == rawget(_G, "WM_Highlight_Wide"), "the message needs the chat font")

  -- test_message_keeps_its_grey_colour_on_the_wide_font
  local r, g, b = preview.messageLabel:GetTextColor()
  local grey = Theme.COLORS.text_secondary
  assert(r == grey[1] and g == grey[2] and b == grey[3], "the message stays grey")

  -- test_plain_whisper_goes_back_to_the_usual_font
  preview.setIncomingPreview("Jaina", "hi", nil)
  assert(preview.senderLabel:GetFontObject() == rawget(_G, "WM_Highlight"), "a plain sender keeps the theme font")
  assert(preview.messageLabel:GetFontObject() == rawget(_G, "WM_Highlight"), "a plain message keeps the theme font")
end
