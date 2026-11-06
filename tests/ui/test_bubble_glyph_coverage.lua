local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

-- A message with "ő" or "ű" draws in the chat font, not as squares.
return function()
  local factory = FakeUI.NewFactory()
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  -- test_hungarian_text_uses_the_wide_font
  local hungarian = BubbleFrame.CreateBubble(factory, parent, { text = "hosszú ő és ű", kind = "user", direction = "in" })
  assert(hungarian.frame._textFS.fontObject == _G.WM_Highlight_Wide, "ő and ű need the chat font")

  -- test_plain_text_keeps_the_usual_font
  local plain = BubbleFrame.CreateBubble(factory, parent, { text = "árvíztükör", kind = "user", direction = "out" })
  assert(plain.frame._textFS.fontObject == _G.WM_Highlight, "Latin-1 accents keep the theme font")
end
