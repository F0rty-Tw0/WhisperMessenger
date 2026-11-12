local GameWhisperTab = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GameWhisperTab")

-- The game's own temporary whisper tabs: CHAT_FRAMES lists frame names,
-- each frame lives at _G[name], FCF_Close shuts one.
local saved = {}
local SAVED_GLOBALS = { "CHAT_FRAMES", "FCF_Close", "FCF_PopInWindow", "C_BattleNet", "Ambiguate" }

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
  _G.FCF_PopInWindow = nil
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

  check("test_prefers_pop_in_so_main_chat_shows_the_player_again", function(closed)
    local poppedIn = {}
    _G.FCF_PopInWindow = function(frame)
      poppedIn[#poppedIn + 1] = frame
    end
    local frame = chatFrame("ChatFrame11", { isTemporary = true, chatType = "WHISPER", chatTarget = "Arthas-Stormrage" })
    GameWhisperTab.CloseFor("wow::WOW::arthas", { channel = "WOW" })
    assert(#poppedIn == 1 and poppedIn[1] == frame, "FCF_PopInWindow gets the frame, as the game's own Close does")
    assert(#closed == 0, "FCF_Close is only the fallback")
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

  check("test_conversation_key_for_character_tab", function()
    local frame = { isTemporary = true, chatType = "WHISPER", chatTarget = "Thrall" }
    local conversations = { ["wow::WOW::thrall"] = { channel = "WOW" }, ["wow::WOW::jaina"] = { channel = "WOW" } }
    local key = GameWhisperTab.ConversationKeyFor(frame, conversations)
    assert(key == "wow::WOW::thrall", "character tab resolves its conversation key, got " .. tostring(key))
  end)

  check("test_conversation_key_for_bnet_tab", function()
    _G.C_BattleNet = {
      GetAccountInfoByID = function(id)
        return id == 42 and { accountName = "|Kq7|k" } or nil
      end,
    }
    local frame = { isTemporary = true, chatType = "BN_WHISPER", chatTarget = "|Kq7|k" }
    local conversations = { ["bnet::BN::friend#1234"] = { channel = "BN", bnetAccountID = 42 } }
    local key = GameWhisperTab.ConversationKeyFor(frame, conversations)
    assert(key == "bnet::BN::friend#1234", "BN tab resolves its conversation key, got " .. tostring(key))
  end)

  check("test_conversation_key_for_non_whisper_frame_is_nil", function()
    local conversations = { ["wow::WOW::thrall"] = { channel = "WOW" } }
    local notTemporary = { isTemporary = false, chatType = "WHISPER", chatTarget = "Thrall" }
    local say = { isTemporary = true, chatType = "SAY", chatTarget = "Thrall" }
    assert(GameWhisperTab.ConversationKeyFor(notTemporary, conversations) == nil, "a player-made window has no key")
    assert(GameWhisperTab.ConversationKeyFor(say, conversations) == nil, "a non-whisper frame has no key")
    assert(GameWhisperTab.ConversationKeyFor(nil, conversations) == nil, "a nil frame has no key")
  end)

  check("test_whisper_tab_ignores_bnet_conversation_with_same_name", function()
    _G.C_BattleNet = {
      GetAccountInfoByID = function()
        return { accountName = "Thrall" }
      end,
    }
    local frame = { isTemporary = true, chatType = "WHISPER", chatTarget = "Thrall" }
    local conversations = { ["bnet::BN::thrall#1"] = { channel = "BN", bnetAccountID = 42 } }
    assert(GameWhisperTab.ConversationKeyFor(frame, conversations) == nil, "chat type must match the channel")
  end)

  check("test_conversation_key_for_skips_secret_chat_type", function()
    local savedIsSecret = _G.issecretvalue
    rawset(_G, "issecretvalue", function(value)
      return value == "WHISPER"
    end)
    local frame = { isTemporary = true, chatType = "WHISPER", chatTarget = "Thrall" }
    local key = GameWhisperTab.ConversationKeyFor(frame, { ["wow::WOW::thrall"] = { channel = "WOW" } })
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(key == nil, "a secret chat type is never compared")
  end)

  check("test_conversation_key_for_asks_secret_before_comparing_target", function()
    local savedIsSecret = _G.issecretvalue
    local asked = {}
    rawset(_G, "issecretvalue", function(value)
      asked[#asked + 1] = value
      return false
    end)
    local frame = { isTemporary = true, chatType = "WHISPER", chatTarget = "" }
    GameWhisperTab.ConversationKeyFor(frame, { ["wow::WOW::thrall"] = { channel = "WOW" } })
    rawset(_G, "issecretvalue", savedIsSecret)
    local askedAboutTarget = false
    for _, value in ipairs(asked) do
      askedAboutTarget = askedAboutTarget or value == ""
    end
    assert(askedAboutTarget, "the secret check runs before any comparison of the target")
  end)
end
