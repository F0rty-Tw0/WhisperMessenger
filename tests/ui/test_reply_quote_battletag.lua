local FakeUI = require("tests.helpers.fake_ui")
local ReplyQuote = require("WhisperMessenger.UI.ChatBubble.ReplyQuote")

return function()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Button", nil, nil)

  -- test_quote_author_hides_battletag_numbers
  ReplyQuote.Apply(factory, frame, { replyTo = { author = "Arthas#1234", snippet = "hi" } }, 300, 8, 6)
  local text = frame._wmReplyQuote._wmLabel.text
  assert(string.find(text, "Arthas", 1, true) and not string.find(text, "#1234", 1, true), "quote hides the BattleTag number: " .. text)
end
