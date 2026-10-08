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

  -- test_clashing_battletags_keep_their_numbers

  do
    DisplayName.SetBattleTags({ "Mike#1234", "Mike#5678", "Arthas#1111" })
    assert(DisplayName.Format("Mike#1234") == "Mike#1234", "a shared name part keeps the number")
    assert(DisplayName.Format("Mike#5678") == "Mike#5678", "both clashing friends keep the number")
    assert(DisplayName.Format("Arthas#1111") == "Arthas", "a unique name part still hides the number")
  end

  -- test_no_clash_hides_the_number

  do
    DisplayName.SetBattleTags({ "Mike#1234", "Jaina#2222" })
    assert(DisplayName.Format("Mike#1234") == "Mike", "no other Mike, so the number hides")
  end

  -- test_same_battletag_twice_is_not_a_clash

  do
    DisplayName.SetBattleTags({ "Mike#1234", "Mike#1234" })
    assert(DisplayName.Format("Mike#1234") == "Mike", "one friend stored twice is still one friend")
  end

  -- test_clash_ignores_case

  do
    DisplayName.SetBattleTags({ "mike#1234", "Mike#5678" })
    assert(DisplayName.Format("mike#1234") == "mike#1234", "mike and Mike clash")
    assert(DisplayName.Format("Mike#5678") == "Mike#5678", "Mike and mike clash")
  end

  -- test_clash_leaves_non_battletag_names_alone

  do
    DisplayName.SetBattleTags({ "Mike#1234", "Mike#5678", "Mike-Area52" })
    assert(DisplayName.Format("Mike-Area52") == "Mike-Area52", "a character name is never a BattleTag")
    assert(DisplayName.Format("Mike") == "Mike", "a plain name is unchanged")
  end

  -- test_option_off_shows_full_tags_with_clashes

  do
    DisplayName.SetBattleTags({ "Mike#1234", "Mike#5678", "Arthas#1111" })
    DisplayName.Configure({ hideBattleTagNumbers = false })
    assert(DisplayName.Format("Arthas#1111") == "Arthas#1111", "option off shows every full tag")
    assert(DisplayName.Format("Mike#1234") == "Mike#1234", "clashing tags stay full too")
    DisplayName.Configure({ hideBattleTagNumbers = true })
  end

  -- test_revision_bumps_when_output_can_change

  do
    local start = DisplayName.Revision()
    DisplayName.Configure({ hideBattleTagNumbers = true })
    assert(DisplayName.Revision() == start, "configuring the same value changes nothing")
    DisplayName.Configure({ hideBattleTagNumbers = false })
    assert(DisplayName.Revision() > start, "flipping the option bumps the revision")
    DisplayName.Configure({ hideBattleTagNumbers = true })

    local afterToggle = DisplayName.Revision()
    DisplayName.SetBattleTags({ "Mike#1234", "Mike#5678", "Arthas#9999" })
    assert(DisplayName.Revision() == afterToggle, "the same clash set does not bump")
    DisplayName.SetBattleTags({ "Mike#1234" })
    assert(DisplayName.Revision() > afterToggle, "a changed clash set bumps the revision")
  end

  -- test_class_color_sender_names_defaults_on

  do
    assert(DisplayName.ClassColorSenderNames() == true, "class-coloured sender names are on by default")
  end

  -- test_configure_class_color_flips_flag_and_bumps_revision

  do
    local r = DisplayName.Revision()
    DisplayName.Configure({ classColorSenderNames = false })
    assert(DisplayName.ClassColorSenderNames() == false, "configuring the flag off turns it off")
    assert(DisplayName.Revision() == r + 1, "flipping the class-colour flag bumps the revision once")
    DisplayName.Configure({ classColorSenderNames = false })
  end

  -- test_configure_class_color_alone_keeps_battletag_rule

  do
    DisplayName.Configure({ hideBattleTagNumbers = true })
    DisplayName.Configure({ classColorSenderNames = true })
    assert(DisplayName.Format("Arthas#1234") == "Arthas", "configuring only the class-colour flag keeps BattleTag numbers hidden")
    DisplayName.Configure({ classColorSenderNames = false })
  end

  -- test_configure_battletag_alone_keeps_class_color_flag

  do
    DisplayName.Configure({ classColorSenderNames = true })
    DisplayName.Configure({ hideBattleTagNumbers = false })
    assert(DisplayName.ClassColorSenderNames() == true, "configuring only the BattleTag option keeps the class-colour flag")
    DisplayName.Configure({ hideBattleTagNumbers = true })
    DisplayName.Configure({ classColorSenderNames = false })
  end

  -- test_show_player_levels_defaults_off

  do
    assert(DisplayName.ShowPlayerLevels() == false, "player levels are hidden by default")
  end

  -- test_configure_show_player_levels_flips_flag_and_bumps_revision

  do
    local r = DisplayName.Revision()
    DisplayName.Configure({ showPlayerLevels = true })
    assert(DisplayName.ShowPlayerLevels() == true, "configuring the flag on turns it on")
    assert(DisplayName.Revision() == r + 1, "flipping the player-levels flag bumps the revision once")
    DisplayName.Configure({ showPlayerLevels = true })
    assert(DisplayName.Revision() == r + 1, "the same value again does not bump")
    DisplayName.Configure({ showPlayerLevels = false })
  end
end
