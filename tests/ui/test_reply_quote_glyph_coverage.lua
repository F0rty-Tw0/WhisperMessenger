local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local ReplyQuote = require("WhisperMessenger.UI.ChatBubble.ReplyQuote")

-- A quoted message with "ő" or "ű" shows them in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local frame = factory.CreateFrame("Frame", nil, nil)

  local function quoteLabel(replyTo)
    ReplyQuote.Apply(factory, frame, { replyTo = replyTo }, 300, 8, 6)
    return frame._wmReplyQuote._wmLabel
  end

  -- test_quote_with_double_acute_letters_uses_the_wide_font
  do
    local label = quoteLabel({ author = "Thrall", snippet = "jössz, főnök?" })
    assert(label:GetFontObject() == rawget(_G, "WM_DisableSmall_Wide"), "the snippet needs the chat font")
  end

  -- test_plain_quote_keeps_the_usual_font
  do
    local label = quoteLabel({ author = "Thrall", snippet = "you coming?" })
    assert(label:GetFontObject() == rawget(_G, "WM_DisableSmall"), "a plain quote keeps the theme font")
  end
end
