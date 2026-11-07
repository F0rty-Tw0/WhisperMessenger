local ChatPrefill = require("WhisperMessenger.Util.ChatPrefill")

-- ChatPrefill opens the game's chat box with text and reports "opening" only
-- while that call runs, so our own edit-box hooks can leave the box alone.

return function()
  local savedUtil = rawget(_G, "ChatFrameUtil")
  local savedGlobal = rawget(_G, "ChatFrame_OpenChat")
  local savedSlash = rawget(_G, "SlashCmdList")
  local savedHash = rawget(_G, "hash_SlashCmdList")
  local savedIsSecure = rawget(_G, "issecurevariable")

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

    -- IsSafe: prefilling makes the game parse the text under our taint, and
    -- that parse moves every pending slash command into the lookup table.
    -- Safe only once the game has already done that itself, securely.
    local function safeState()
      rawset(_G, "SlashCmdList", {})
      rawset(_G, "hash_SlashCmdList", { ["/GINVITE"] = function() end })
      rawset(_G, "issecurevariable", function(tbl, key)
        return tbl == _G.hash_SlashCmdList and key == "/GINVITE"
      end)
    end

    -- test_is_safe_when_command_already_imported_securely
    safeState()
    assert(ChatPrefill.IsSafe("/ginvite Bob") == true, "secure, imported command is safe")

    -- test_is_unsafe_without_slash_command_hash
    safeState()
    rawset(_G, "hash_SlashCmdList", nil)
    assert(ChatPrefill.IsSafe("/ginvite Bob") == false, "no hash table is unsafe")

    -- test_is_unsafe_when_command_not_imported_yet
    safeState()
    rawset(_G, "hash_SlashCmdList", {})
    assert(ChatPrefill.IsSafe("/ginvite Bob") == false, "command missing from the hash is unsafe")

    -- test_is_unsafe_when_command_entry_is_tainted
    safeState()
    rawset(_G, "issecurevariable", function()
      return false, "SomeAddon"
    end)
    assert(ChatPrefill.IsSafe("/ginvite Bob") == false, "tainted hash entry is unsafe")

    -- test_is_unsafe_without_issecurevariable
    safeState()
    rawset(_G, "issecurevariable", nil)
    assert(ChatPrefill.IsSafe("/ginvite Bob") == false, "missing issecurevariable is unsafe")

    -- test_is_unsafe_when_issecurevariable_throws
    safeState()
    rawset(_G, "issecurevariable", function()
      error("boom")
    end)
    assert(ChatPrefill.IsSafe("/ginvite Bob") == false, "throwing issecurevariable is unsafe")

    -- test_is_unsafe_with_pending_slash_commands
    safeState()
    rawset(_G, "SlashCmdList", { SOMEADDON = function() end })
    assert(ChatPrefill.IsSafe("/ginvite Bob") == false, "pending slash commands are unsafe")

    -- test_is_unsafe_without_slash_command_list
    safeState()
    rawset(_G, "SlashCmdList", nil)
    assert(ChatPrefill.IsSafe("/ginvite Bob") == false, "missing SlashCmdList is unsafe")

    -- test_is_unsafe_for_text_without_slash_command
    safeState()
    assert(ChatPrefill.IsSafe("ginvite Bob") == false, "plain text is not a known command")
    assert(ChatPrefill.IsSafe(nil) == false, "nil text is unsafe")
  end)

  rawset(_G, "ChatFrameUtil", savedUtil)
  rawset(_G, "ChatFrame_OpenChat", savedGlobal)
  rawset(_G, "SlashCmdList", savedSlash)
  rawset(_G, "hash_SlashCmdList", savedHash)
  rawset(_G, "issecurevariable", savedIsSecure)
  assert(ok, err)
end
