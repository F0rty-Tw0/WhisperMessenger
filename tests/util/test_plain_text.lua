local PlainText = require("WhisperMessenger.Util.PlainText")

-- Chat text without WoW's escape codes: what a player would type back.
return function()
  -- test_strips_color_codes
  do
    assert(PlainText.Strip("|cffff0000red|r text") == "red text", "color codes are dropped")
  end

  -- test_hyperlink_keeps_its_label
  do
    local link = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"
    assert(PlainText.Strip("look " .. link) == "look [Thunderfury]", "a link becomes its [Label]")
  end

  -- test_strips_textures_and_atlases
  do
    local text = "a|TInterface\\Icons\\INV_Misc_QuestionMark:16|tb|Araid-icon:16:16|ac"
    assert(PlainText.Strip(text) == "abc", "textures and atlases are dropped")
  end

  -- test_plain_text_passes_through
  do
    assert(PlainText.Strip("hello there") == "hello there", "plain text is unchanged")
  end
end
