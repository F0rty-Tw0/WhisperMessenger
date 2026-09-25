local TextLimits = require("WhisperMessenger.Util.TextLimits")

return function()
  -- test_cap_bytes_keeps_short_text
  assert(TextLimits.CapBytes("hello", 10) == "hello", "short text is unchanged")

  -- test_cap_bytes_cuts_ascii_at_limit
  assert(TextLimits.CapBytes(string.rep("a", 300), 255) == string.rep("a", 255), "ascii cut at the byte limit")

  -- test_cap_bytes_never_splits_a_utf8_character
  -- "é" is two bytes; a 3-byte cap must drop the whole second "é".
  assert(TextLimits.CapBytes("aéé", 4) == "aé", "cut lands on a character boundary")
  assert(TextLimits.CapBytes("aéé", 5) == "aéé", "exact fit keeps every character")

  -- test_cap_bytes_cut_at_every_byte_stays_on_a_character_boundary
  -- 1-, 2-, 3- and 4-byte characters: each cut keeps only whole characters.
  local mixed = "aé€😀b"
  local boundaries = { [0] = "", "a", "a", "aé", "aé", "aé", "aé€", "aé€", "aé€", "aé€", "aé€😀", "aé€😀b" }
  for cap = 0, #mixed do
    assert(TextLimits.CapBytes(mixed, cap) == boundaries[cap], "cap " .. cap)
  end

  -- test_trim_strips_surrounding_whitespace
  assert(TextLimits.Trim("  Thrall 	") == "Thrall", "surrounding whitespace removed")
  assert(TextLimits.Trim("a b") == "a b", "inner whitespace kept")

  -- test_trim_blank_or_non_string_is_nil
  assert(TextLimits.Trim("   ") == nil and TextLimits.Trim("") == nil, "blank is nil")
  assert(TextLimits.Trim(nil) == nil and TextLimits.Trim(42) == nil, "non-string is nil")

  -- test_cap_chars_counts_utf8_characters_not_bytes
  assert(TextLimits.CapChars("Zoëabc", 3) == "Zoë", "three characters, four bytes")
  assert(TextLimits.CapChars("abc", 32) == "abc", "short text is unchanged")
  assert(TextLimits.CapChars(string.rep("x", 40), 32) == string.rep("x", 32), "ascii cut at the character limit")
end
