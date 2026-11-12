local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local ReplyBanner = require("WhisperMessenger.UI.ConversationPane.ReplyBanner")

-- The "Replying to" strip shows "ő" or "ű" in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local pane = factory.CreateFrame("Frame", nil, nil)
  local banner = ReplyBanner.Create(factory, pane)
  local label
  for _, child in ipairs(banner.frame.children) do
    if child.frameType == "FontString" and child.template == "WM_HighlightSmall" then
      label = child
    end
  end
  assert(label ~= nil, "banner label found")

  -- test_reply_to_a_double_acute_snippet_uses_the_wide_font
  banner.setReply({ author = "Kőszívű", snippet = "szia" })
  assert(label:GetFontObject() == rawget(_G, "WM_HighlightSmall_Wide"), "the name needs the chat font")

  -- test_plain_reply_keeps_the_usual_font
  banner.setReply({ author = "Thrall", snippet = "hi" })
  assert(label:GetFontObject() == rawget(_G, "WM_HighlightSmall"), "a plain reply keeps the theme font")
end
