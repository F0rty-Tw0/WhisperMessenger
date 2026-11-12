local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")

-- A contact note with "ő" or "ű" shows them in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)
  local header = HeaderView.Create(factory, pane, nil)
  HeaderView.Relayout(header, 600)

  -- test_note_with_double_acute_letters_uses_the_wide_font
  HeaderView.Refresh(header, { displayName = "Arthas", channel = "WOW", note = "főnök" }, {}, nil)
  assert(header.headerNote:IsShown(), "note shown")
  assert(header.headerNote:GetFontObject() == rawget(_G, "WM_DisableSmall_Wide"), "the note needs the chat font")

  -- test_plain_note_keeps_the_usual_font
  HeaderView.Refresh(header, { displayName = "Arthas", channel = "WOW", note = "raid lead" }, {}, nil)
  assert(header.headerNote:GetFontObject() == rawget(_G, "WM_DisableSmall"), "a plain note keeps the theme font")
end
