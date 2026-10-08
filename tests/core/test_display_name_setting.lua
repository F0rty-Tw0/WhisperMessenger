local DisplayNameSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.DisplayNameSetting")

return function()
  local last = {}
  local stub = {
    Configure = function(opts)
      last = opts
    end,
  }

  -- test_battletag_key_defaults_to_hiding_numbers

  do
    assert(DisplayNameSetting.Apply(stub, "hideBattleTagNumbers", nil) == true, "the BattleTag key is handled")
    assert(last.hideBattleTagNumbers == true, "an unset BattleTag choice hides the numbers")
    assert(last.classColorSenderNames == nil, "the BattleTag key leaves the class colour choice alone")
  end

  -- test_class_color_key_defaults_to_on

  do
    assert(DisplayNameSetting.Apply(stub, "classColorSenderNames", nil) == true, "the class colour key is handled")
    assert(last.classColorSenderNames == true, "an unset class colour choice is on")
    assert(last.hideBattleTagNumbers == nil, "the class colour key leaves the BattleTag choice alone")
  end

  -- test_player_levels_key_is_opt_in

  do
    local DisplayName = require("WhisperMessenger.Util.DisplayName")
    assert(DisplayNameSetting.Apply(DisplayName, "showPlayerLevels", true) == true, "the player levels key is handled")
    assert(DisplayName.ShowPlayerLevels() == true, "a true choice shows levels")
    assert(DisplayNameSetting.Apply(DisplayName, "showPlayerLevels", nil) == true, "an unset choice is handled")
    assert(DisplayName.ShowPlayerLevels() == false, "an unset player levels choice is off")
  end

  -- test_other_keys_are_ignored

  do
    local before = last
    assert(DisplayNameSetting.Apply(stub, "fontSize", 12) == false, "other keys are not handled")
    assert(last == before, "other keys leave the display name config alone")
  end

  -- test_missing_configure_is_ignored

  do
    assert(DisplayNameSetting.Apply({}, "classColorSenderNames", true) == false, "no Configure means nothing to apply")
  end
end
