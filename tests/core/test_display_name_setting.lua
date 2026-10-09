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

  -- test_player_levels_key_toggles_seen_level_events

  do
    local DisplayName = require("WhisperMessenger.Util.DisplayName")
    local enabledCalls = {}
    local fakeEvents = {
      SetEnabled = function(on)
        enabledCalls[#enabledCalls + 1] = on
      end,
    }
    DisplayNameSetting.Apply(DisplayName, "showPlayerLevels", true, fakeEvents)
    DisplayNameSetting.Apply(DisplayName, "showPlayerLevels", nil, fakeEvents)
    assert(#enabledCalls == 2, "each player levels change reaches the level recorder")
    assert(enabledCalls[1] == true, "turning levels on starts recording")
    assert(enabledCalls[2] == false, "an unset choice stops recording")
  end

  -- test_other_keys_leave_seen_level_events_alone

  do
    local touched = false
    local fakeEvents = {
      SetEnabled = function()
        touched = true
      end,
    }
    DisplayNameSetting.Apply(stub, "classColorSenderNames", true, fakeEvents)
    assert(touched == false, "other keys do not touch the level recorder")
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
