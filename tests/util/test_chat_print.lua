local ChatPrint = require("WhisperMessenger.Util.ChatPrint")

-- Addon notices go to the default chat frame with the gold addon prefix.
return function()
  -- test_prints_with_the_addon_prefix
  do
    local lines = {}
    rawset(_G, "DEFAULT_CHAT_FRAME", {
      AddMessage = function(_, text)
        lines[#lines + 1] = text
      end,
    })
    assert(ChatPrint.Print("hello") == true, "printed")
    assert(lines[1] == "|cffffd100WhisperMessenger:|r hello", "prefixed: " .. tostring(lines[1]))
  end

  -- test_explicit_frame_wins
  do
    local lines = {}
    ChatPrint.Print("tip", {
      AddMessage = function(_, text)
        lines[#lines + 1] = text
      end,
    })
    assert(lines[1] == "|cffffd100WhisperMessenger:|r tip", "sent to the given frame")
  end

  -- test_no_chat_frame_is_safe
  do
    rawset(_G, "DEFAULT_CHAT_FRAME", nil)
    assert(ChatPrint.Print("nowhere") == false, "nothing to print to")
  end
end
