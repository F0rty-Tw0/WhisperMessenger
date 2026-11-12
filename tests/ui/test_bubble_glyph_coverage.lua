local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

-- A message with "ő" or "ű" draws in the chat font, not as squares.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  -- test_hungarian_text_uses_the_wide_font
  do
    local bubble = BubbleFrame.CreateBubble(factory, parent, { text = "hosszú ő és ű", kind = "user", direction = "in" })
    assert(bubble.text:GetFontObject() == rawget(_G, "WM_Highlight_Wide"), "ő and ű need the chat font")
  end

  -- test_latin1_text_keeps_the_usual_font
  do
    local bubble = BubbleFrame.CreateBubble(factory, parent, { text = "árvíztükör", kind = "user", direction = "out" })
    assert(bubble.text:GetFontObject() == rawget(_G, "WM_Highlight"), "Latin-1 accents keep the theme font")
  end

  -- test_font_colour_preset_survives_the_swap
  do
    Fonts.SetFontColor("gold")
    local bubble = BubbleFrame.CreateBubble(factory, parent, { text = "tűzőgép", kind = "user", direction = "in" })
    Fonts.SetFontColor("default")
    local r, g, b = bubble.text:GetTextColor()
    assert(r == 1 and g > 0.8 and g < 0.85 and b == 0, "the gold text colour stays, got " .. tostring(r) .. "," .. tostring(g) .. "," .. tostring(b))
  end
end
