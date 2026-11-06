local SafeText = require("WhisperMessenger.Model.GroupChatProtocol.SafeText")

return function()
  -- test_plain_text_is_unchanged
  do
    assert(SafeText.Clean("hello there") == "hello there")
  end

  -- test_item_links_stay_clickable
  do
    local link = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"
    assert(SafeText.Clean("look " .. link .. "!") == "look " .. link .. "!", "colored item link kept")
    local named = "|cnIQ4:|Hitem:1234::::|h[Sword]|h|r"
    assert(SafeText.Clean(named) == named, "quality-color item link kept")
    local bare = "|Hspell:1234|h[Fireball]|h"
    assert(SafeText.Clean(bare) == bare, "uncolored spell link kept")
  end

  -- test_unknown_link_types_become_their_label
  do
    assert(SafeText.Clean("|cffff0000|Haddon:evil:1|h[Click me]|h|r") == "[Click me]")
  end

  -- test_textures_atlases_and_colors_are_removed
  do
    assert(SafeText.Clean("a|TInterface\\Icons\\X:900|tb") == "ab")
    assert(SafeText.Clean("a|A:atlas:20:20|ab") == "ab")
    assert(SafeText.Clean("|cffff0000red|r text") == "red text")
    assert(SafeText.Clean("|Kq12|k") == nil, "protected name tokens go")
  end

  -- test_stray_escapes_show_literally
  do
    assert(SafeText.Clean("a|nb") == "a||nb", "an unknown escape is shown as typed")
    assert(SafeText.Clean("a||b") == "a||b", "a typed pipe stays a typed pipe")
  end

  -- test_control_characters_cannot_forge_placeholders
  do
    assert(SafeText.Clean("x\2" .. "1\3y") == "x1y")
    assert(SafeText.Clean("line\nbreak") == "linebreak")
  end

  -- test_blank_results_are_nil
  do
    assert(SafeText.Clean("   ") == nil)
    assert(SafeText.Clean(nil) == nil)
  end
end
