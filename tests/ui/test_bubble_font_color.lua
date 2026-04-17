local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

return function()
  Fonts.Initialize("default")

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  -- test_default_font_color_uses_theme_colors

  do
    Fonts.SetFontColor("default")
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      text = "Hello",
      kind = "user",
      direction = "in",
    })
    local r, g, b = bubble.text:GetTextColor()
    -- Theme text_received is the default for incoming — just verify it's set
    assert(type(r) == "number", "test_default_color: r should be a number")
    assert(type(g) == "number", "test_default_color: g should be a number")
    assert(type(b) == "number", "test_default_color: b should be a number")
  end

  -- test_gold_font_color_overrides_incoming_text

  do
    Fonts.SetFontColor("gold")
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      text = "Hello",
      kind = "user",
      direction = "in",
    })
    local r, g, b = bubble.text:GetTextColor()
    assert(r == 1, "test_gold_incoming: r should be 1, got: " .. tostring(r))
    assert(g > 0.8 and g < 0.85, "test_gold_incoming: g should be ~0.82, got: " .. tostring(g))
    assert(b == 0, "test_gold_incoming: b should be 0, got: " .. tostring(b))
  end

  -- test_gold_font_color_overrides_outgoing_text

  do
    Fonts.SetFontColor("gold")
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      text = "Hello",
      kind = "user",
      direction = "out",
    })
    local r, g, b = bubble.text:GetTextColor()
    assert(r == 1, "test_gold_outgoing: r should be 1, got: " .. tostring(r))
    assert(g > 0.8 and g < 0.85, "test_gold_outgoing: g should be ~0.82, got: " .. tostring(g))
    assert(b == 0, "test_gold_outgoing: b should be 0, got: " .. tostring(b))
  end

  -- test_font_color_does_not_affect_system_messages

  do
    Fonts.SetFontColor("gold")
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      text = "System notice",
      kind = "system",
      direction = "in",
    })
    local r, g, b = bubble.text:GetTextColor()
    -- System messages should NOT use the font color override
    -- They should use Theme.COLORS.text_system
    local isGold = (r == 1 and g > 0.8 and g < 0.85 and b == 0)
    assert(not isGold, "test_system_not_affected: system messages should not use font color override")
  end

  -- test_font_color_reset_to_default_restores_theme

  do
    Fonts.SetFontColor("gold")
    Fonts.SetFontColor("default")
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      text = "Hello",
      kind = "user",
      direction = "in",
    })
    local r, _, b = bubble.text:GetTextColor()
    local isGold = (r == 1 and b == 0)
    -- After resetting to default, it should use theme colors, not gold
    -- Theme text_received is unlikely to be exactly {1, 0.82, 0, 1}
    assert(not isGold, "test_reset_default: should not be gold after reset")
  end

  Fonts.SetFontColor("default")
  print("  All bubble font color tests passed")
end
