local MentionHighlight = require("WhisperMessenger.UI.ChatBubble.MentionHighlight")

local HEX = "ffc69b6d"

local function colorize(text, name)
  return MentionHighlight.Colorize(text, name, HEX)
end

return function()
  -- test_name_without_at_sign_is_coloured
  assert(colorize("hey Ara, ready?", "Ara") == "hey |cffc69b6dAra|r, ready?", "plain name coloured")

  -- test_at_sign_stays_outside_the_colour
  assert(colorize("@Ara pls", "Ara") == "@|cffc69b6dAra|r pls", "@ prefix kept, name coloured")

  -- test_original_casing_is_kept
  assert(colorize("heal me ARA", "Ara") == "heal me |cffc69b6dARA|r", "casing preserved")

  -- test_every_occurrence_is_coloured
  assert(colorize("Ara? Ara!", "Ara") == "|cffc69b6dAra|r? |cffc69b6dAra|r!", "both hits coloured")

  -- test_name_inside_a_longer_word_is_left_alone
  assert(colorize("off to Arathi, Tiara", "Ara") == "off to Arathi, Tiara", "no partial-word colour")

  -- test_link_contents_are_never_touched
  local link = "|cffffd000|Hplayer:Ara-Realm|h[Ara]|h|r"
  assert(colorize(link .. " Ara", "Ara") == link .. " |cffc69b6dAra|r", "link kept byte-exact")

  -- test_texture_escapes_are_never_touched
  local texture = "|TInterface\\Ara\\Icon:0|t"
  assert(colorize(texture .. "Ara", "Ara") == texture .. "|cffc69b6dAra|r", "texture path untouched")

  -- test_unterminated_escape_leaves_the_rest_alone
  assert(colorize("Ara |cffff0000Ara", "Ara") == "|cffc69b6dAra|r |cffff0000Ara", "open colour run left alone")

  -- test_missing_name_or_colour_returns_text_unchanged
  assert(MentionHighlight.Colorize("hey Ara", nil, HEX) == "hey Ara", "no name")
  assert(MentionHighlight.Colorize("hey Ara", "Ara", nil) == "hey Ara", "no colour")

  -- test_class_hex_comes_from_raid_class_colors
  local savedColors = _G.RAID_CLASS_COLORS
  _G.RAID_CLASS_COLORS = { WARRIOR = { r = 198 / 255, g = 155 / 255, b = 109 / 255 } }
  assert(MentionHighlight.ClassHex("WARRIOR") == HEX, "hex " .. tostring(MentionHighlight.ClassHex("WARRIOR")))
  assert(MentionHighlight.ClassHex("NOPE") == nil, "unknown class")
  assert(MentionHighlight.ClassHex(nil) == nil, "no class")
  _G.RAID_CLASS_COLORS = savedColors
end
