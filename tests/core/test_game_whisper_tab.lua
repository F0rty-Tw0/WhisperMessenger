local GameWhisperTab = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GameWhisperTab")

-- The game's own temporary whisper tabs: CHAT_FRAMES lists frame names,
-- each frame lives at _G[name], FCF_Close shuts one.
local saved = {}
local SAVED_GLOBALS = { "CHAT_FRAMES", "FCF_Close", "C_BattleNet", "Ambiguate" }

local function chatFrame(name, fields)
  local frame = { name = name, inUse = true }
  for key, value in pairs(fields or {}) do
    frame[key] = value
  end
  _G[name] = frame
  _G.CHAT_FRAMES[#_G.CHAT_FRAMES + 1] = name
  return frame
end

local function setUp()
  for _, name in ipairs(SAVED_GLOBALS) do
    saved[name] = _G[name]
  end
  local closed = {}
  _G.CHAT_FRAMES = {}
  _G.FCF_Close = function(frame)
    closed[#closed + 1] = frame
  end
  _G.Ambiguate = function(name)
    return (string.gsub(name, "%-Stormrage$", ""))
  end
  return closed
end

local function tearDown()
  for _, frameName in ipairs(_G.CHAT_FRAMES or {}) do
    _G[frameName] = nil
  end
  for _, name in ipairs(SAVED_GLOBALS) do
    _G[name] = saved[name]
  end
end

local function check(name, body)
  local closed = setUp()
  local ok, err = pcall(body, closed)
  tearDown()
  if not ok then
    error(name .. ": " .. tostring(err), 0)
  end
end

return function()
  check("test_closes_matching_temporary_whisper_frame", function(closed)
    local frame = chatFrame("ChatFrame11", { isTemporary = true, chatType = "WHISPER", chatTarget = "Arthas-Stormrage" })
    GameWhisperTab.CloseFor("wow::WOW::arthas", { channel = "WOW" })
    assert(#closed == 1 and closed[1] == frame, "FCF_Close gets the frame")
  end)

  check("test_matches_cross_realm_name_case_insensitively", function(closed)
    chatFrame("ChatFrame11", { isTemporary = true, chatType = "WHISPER", chatTarget = "JAINA-Proudmoore" })
    GameWhisperTab.CloseFor("wow::WOW::jaina-proudmoore", { channel = "WOW" })
    assert(#closed == 1, "cross-realm tab closed")
  end)

  check("test_leaves_non_temporary_frame_with_same_name", function(closed)
    chatFrame("ChatFrame4", { chatType = "WHISPER", chatTarget = "Arthas" })
    GameWhisperTab.CloseFor("wow::WOW::arthas", { channel = "WOW" })
    assert(#closed == 0, "a player-made chat window stays")
  end)

  check("test_leaves_other_players_tabs", function(closed)
    chatFrame("ChatFrame11", { isTemporary = true, chatType = "WHISPER", chatTarget = "Thrall" })
    GameWhisperTab.CloseFor("wow::WOW::arthas", { channel = "WOW" })
    assert(#closed == 0, "another player's tab stays")
  end)

  check("test_skips_tab_already_closed", function(closed)
    chatFrame("ChatFrame11", { isTemporary = true, inUse = false, chatType = "WHISPER", chatTarget = "Arthas" })
    GameWhisperTab.CloseFor("wow::WOW::arthas", { channel = "WOW" })
    assert(#closed == 0, "a recycled tab is not closed again")
  end)

  check("test_closes_battle_net_whisper_tab_by_account_name", function(closed)
    _G.C_BattleNet = {
      GetAccountInfoByID = function(id)
        return id == 42 and { accountName = "|Kq7|k" } or nil
      end,
    }
    local frame = chatFrame("ChatFrame11", { isTemporary = true, chatType = "BN_WHISPER", chatTarget = "|Kq7|k" })
    GameWhisperTab.CloseFor("bnet::BN::friend#1234", { channel = "BN", bnetAccountID = 42, battleTag = "Friend#1234" })
    assert(#closed == 1 and closed[1] == frame, "BN whisper tab closed")
  end)

  check("test_battle_net_tab_ignores_character_whisper_tab", function(closed)
    _G.C_BattleNet = {
      GetAccountInfoByID = function()
        return { accountName = "Arthas" }
      end,
    }
    chatFrame("ChatFrame11", { isTemporary = true, chatType = "WHISPER", chatTarget = "Arthas" })
    GameWhisperTab.CloseFor("bnet::BN::friend#1234", { channel = "BN", bnetAccountID = 42 })
    assert(#closed == 0, "chat type must match the conversation channel")
  end)

  check("test_missing_fcf_close_is_a_no_op", function()
    _G.FCF_Close = nil
    chatFrame("ChatFrame11", { isTemporary = true, chatType = "WHISPER", chatTarget = "Arthas" })
    GameWhisperTab.CloseFor("wow::WOW::arthas", { channel = "WOW" })
  end)

  check("test_missing_chat_frames_list_is_a_no_op", function(closed)
    _G.CHAT_FRAMES = nil
    GameWhisperTab.CloseFor("wow::WOW::arthas", { channel = "WOW" })
    _G.CHAT_FRAMES = {}
    assert(#closed == 0, "nothing to close")
  end)

  check("test_secret_chat_target_is_skipped", function(closed)
    local savedIsSecret = _G.issecretvalue
    _G.issecretvalue = function(value)
      return value == "Arthas"
    end
    chatFrame("ChatFrame11", { isTemporary = true, chatType = "WHISPER", chatTarget = "Arthas" })
    GameWhisperTab.CloseFor("wow::WOW::arthas", { channel = "WOW" })
    _G.issecretvalue = savedIsSecret
    assert(#closed == 0, "a secret name is never compared")
  end)
end
