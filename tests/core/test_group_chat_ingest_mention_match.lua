local Mention = require("WhisperMessenger.Core.Ingest.GroupChatIngest.Mention")

return function()
  -- test_name_anywhere_as_a_word_matches
  assert(Mention.Matches("hey Ara, ready?", "Ara") == true, "name followed by punctuation")
  assert(Mention.Matches("Ara", "Ara") == true, "name alone")
  assert(Mention.Matches("heal me ara", "Ara") == true, "name at the end, lower case")

  -- test_match_is_case_insensitive
  assert(Mention.Matches("ARA pls", "Ara") == true, "upper case text")

  -- test_name_inside_a_longer_word_does_not_match
  assert(Mention.Matches("going to Arathi", "Ara") == false, "prefix of a word")
  assert(Mention.Matches("Tiara drops", "Ara") == false, "suffix of a word")
  assert(Mention.Matches("Ara2 is an alt", "Ara") == false, "digit continues the word")

  -- test_accented_letter_continues_the_word
  assert(Mention.Matches("Araé is here", "Ara") == false, "multi-byte letter continues the word")

  -- test_second_occurrence_is_found
  assert(Mention.Matches("Arathi then Ara", "Ara") == true, "keeps scanning past a non-word hit")

  -- test_pattern_characters_in_name_are_literal
  assert(Mention.Matches("Ar.a", "Ar.a") == true and Mention.Matches("Arxa", "Ar.a") == false, "name is matched literally")

  -- test_missing_inputs_never_match
  assert(Mention.Matches(nil, "Ara") == false, "no text")
  assert(Mention.Matches("Ara", nil) == false, "no name")
  assert(Mention.Matches("Ara", "") == false, "empty name")

  -- test_text_that_throws_on_string_ops_is_skipped
  local poisoned = setmetatable({}, {
    __index = function()
      error("secret string value tainted")
    end,
  })
  assert(Mention.Matches(poisoned, "Ara") == false, "non-string text is never inspected")

  -- test_player_name_is_read_once_per_session
  local saved = _G.UnitName
  local calls = 0
  rawset(_G, "UnitName", function()
    calls = calls + 1
    return "Ara"
  end)
  assert(Mention.PlayerName() == "Ara" and Mention.PlayerName() == "Ara", "player name")
  assert(calls == 1, "UnitName read once, got " .. calls)
  rawset(_G, "UnitName", saved)
end
