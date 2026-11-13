local ChatPrefill = require("WhisperMessenger.Util.ChatPrefill")

-- Protected commands (/use, /target): the game's IsSecureCmd knows them.

return function()
  local savedIsSecureCmd = rawget(_G, "IsSecureCmd")

  local ok, err = pcall(function()
    rawset(_G, "IsSecureCmd", function(command)
      return string.upper(command) == "/USE"
    end)

    -- test_is_protected_command_asks_the_game
    assert(ChatPrefill.IsProtectedCommand("/use Hearthstone") == true, "/use is protected")
    assert(ChatPrefill.IsProtectedCommand("/roll 100") == false, "/roll is not protected")

    -- test_is_protected_command_needs_a_slash_command
    assert(ChatPrefill.IsProtectedCommand(nil) == false, "nil is not protected")
    assert(ChatPrefill.IsProtectedCommand("use Hearthstone") == false, "plain text is not protected")

    -- test_is_protected_command_answers_no_when_the_game_check_throws
    rawset(_G, "IsSecureCmd", function()
      error("boom")
    end)
    assert(ChatPrefill.IsProtectedCommand("/use Hearthstone") == false, "throwing IsSecureCmd -> not protected")

    -- test_is_protected_command_answers_no_without_the_game_check
    rawset(_G, "IsSecureCmd", nil)
    assert(ChatPrefill.IsProtectedCommand("/use Hearthstone") == false, "no IsSecureCmd -> not protected")
  end)

  rawset(_G, "IsSecureCmd", savedIsSecureCmd)
  assert(ok, err)
end
