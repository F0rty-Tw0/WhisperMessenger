local ChatPrefill = require("WhisperMessenger.Util.ChatPrefill")

-- ChatPrefill opens the game's chat box with text and reports "opening" only
-- while that call runs, so our own edit-box hooks can leave the box alone.

return function()
  local savedUtil = rawget(_G, "ChatFrameUtil")
  local savedGlobal = rawget(_G, "ChatFrame_OpenChat")

  local ok, err = pcall(function()
    -- test_open_passes_text_and_flags_only_during_the_call
    local seen = {}
    rawset(_G, "ChatFrame_OpenChat", nil)
    rawset(_G, "ChatFrameUtil", {
      OpenChat = function(text)
        seen[#seen + 1] = { text = text, opening = ChatPrefill.IsOpening() }
      end,
    })
    assert(ChatPrefill.IsOpening() == false, "not opening before the call")
    ChatPrefill.Open("/ginvite Arthas")
    assert(seen[1].text == "/ginvite Arthas", "passes the text, got " .. tostring(seen[1].text))
    assert(seen[1].opening == true, "flags opening while the game opens the box")
    assert(ChatPrefill.IsOpening() == false, "clears the flag after the call")

    -- test_open_clears_flag_and_rethrows_when_game_errors
    rawset(_G, "ChatFrameUtil", {
      OpenChat = function()
        error("boom", 0)
      end,
    })
    local opened, openErr = pcall(ChatPrefill.Open, "/ginvite Arthas")
    assert(not opened and openErr == "boom", "rethrows the game's error, got " .. tostring(openErr))
    assert(ChatPrefill.IsOpening() == false, "clears the flag even when the game errors")
  end)

  rawset(_G, "ChatFrameUtil", savedUtil)
  rawset(_G, "ChatFrame_OpenChat", savedGlobal)
  assert(ok, err)
end
