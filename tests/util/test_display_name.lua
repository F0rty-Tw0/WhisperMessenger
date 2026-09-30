local DisplayName = require("WhisperMessenger.Util.DisplayName")

return function()
  -- test_hides_battletag_numbers_by_default

  do
    assert(DisplayName.Format("Arthas#1234") == "Arthas", "BattleTag numbers are hidden by default")
  end

  -- test_leaves_character_names_untouched

  do
    assert(DisplayName.Format("Jaina-Proudmoore") == "Jaina-Proudmoore", "Name-Realm must not change")
    assert(DisplayName.Format("Thrall") == "Thrall", "a plain name must not change")
  end

  -- test_only_strips_a_trailing_number_suffix

  do
    assert(DisplayName.Format("Sylvanas#Windrunner") == "Sylvanas#Windrunner", "a non-numeric suffix is not a BattleTag number")
    assert(DisplayName.Format("#1234") == "#1234", "a bare number keeps its text so the label is never blank")
  end

  -- test_passes_non_strings_through

  do
    assert(DisplayName.Format(nil) == nil, "nil stays nil")
  end

  -- test_shows_full_battletag_when_option_is_off

  do
    DisplayName.Configure({ hideBattleTagNumbers = false })
    assert(DisplayName.Format("Arthas#1234") == "Arthas#1234", "the full BattleTag shows when the option is off")
    DisplayName.Configure({ hideBattleTagNumbers = true })
    assert(DisplayName.Format("Arthas#1234") == "Arthas", "turning the option back on hides the numbers again")
  end

  -- test_configure_ignores_missing_values

  do
    DisplayName.Configure({})
    DisplayName.Configure(nil)
    assert(DisplayName.Format("Arthas#1234") == "Arthas", "an empty configure keeps the current choice")
  end
end
