local Initials = require("WhisperMessenger.Util.Initials")

local function check(name, expected)
  local actual = Initials.FromName(name)
  assert(actual == expected, string.format("initials of %q: expected %q, got %q", tostring(name), expected, tostring(actual)))
end

return function()
  -- test_single_ascii_word_takes_two_letters_uppercased
  check("Jaina", "JA")

  -- test_two_words_take_each_first_letter
  check("Big Bob", "BB")

  -- test_realm_suffix_is_ignored
  check("Jaina-Proudmoore", "JA")

  -- test_battletag_number_is_ignored
  check("Bob#1234", "BO")

  -- test_accented_latin_keeps_whole_characters
  check("Élodie", "ÉL")

  -- test_cyrillic_keeps_whole_characters_and_case
  check("Наташа", "На")

  -- test_cjk_name_takes_one_character
  check("李小龙", "李")

  -- test_hangul_name_takes_one_character
  check("김철수", "김")

  -- test_single_letter_name
  check("J", "J")

  -- test_leading_spaces_are_skipped
  check("  anna", "AN")

  -- test_empty_and_nil_give_empty_string
  check("", "")
  check("   ", "")
  check(nil, "")
end
