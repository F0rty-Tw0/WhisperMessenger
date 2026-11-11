local GameChatRead = require("WhisperMessenger.Core.Bootstrap.GameChatRead")

local SAVED_GLOBALS = { "hooksecurefunc", "FCF_Tab_OnClick", "ChatFrame3", "ChatFrame4" }
local saved = {}

local function whisperFrame(target)
  return { isTemporary = true, chatType = "WHISPER", chatTarget = target }
end

local function newRuntime(unreadCount)
  local refreshes = 0
  local runtime = {
    store = {
      conversations = {
        ["wow::WOW::thrall"] = { channel = "WOW", unreadCount = unreadCount or 0 },
        ["wow::WOW::jaina"] = { channel = "WOW", unreadCount = 3 },
      },
    },
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  }
  return runtime, function()
    return refreshes
  end
end

-- Installs the hook against a stubbed hooksecurefunc and hands back the
-- captured post-hook plus how many times hooksecurefunc ran.
local function install(runtime, isSuspended)
  local captured = { hookedName = nil, fn = nil, installs = 0 }
  rawset(_G, "hooksecurefunc", function(name, fn)
    captured.installs = captured.installs + 1
    captured.hookedName = name
    captured.fn = fn
  end)
  GameChatRead.InstallTabHook(runtime, isSuspended or function()
    return false
  end)
  return captured
end

local function tab(id)
  return {
    GetID = function()
      return id
    end,
  }
end

local function check(name, body)
  for _, key in ipairs(SAVED_GLOBALS) do
    saved[key] = rawget(_G, key)
  end
  rawset(_G, "FCF_Tab_OnClick", function() end)
  rawset(_G, "ChatFrame3", whisperFrame("Thrall"))
  rawset(_G, "ChatFrame4", whisperFrame("Jaina"))
  local ok, err = pcall(body)
  for _, key in ipairs(SAVED_GLOBALS) do
    rawset(_G, key, saved[key])
  end
  if not ok then
    error(name .. ": " .. tostring(err), 0)
  end
end

return function()
  check("test_hooks_the_game_tab_click_function", function()
    local runtime = newRuntime(2)
    local captured = install(runtime)
    assert(captured.installs == 1 and captured.hookedName == "FCF_Tab_OnClick", "post-hooks FCF_Tab_OnClick once")
  end)

  check("test_tab_click_marks_matching_conversation_read", function()
    local runtime, refreshCount = newRuntime(2)
    local captured = install(runtime)
    captured.fn(tab(3), "LeftButton")
    local conversation = runtime.store.conversations["wow::WOW::thrall"]
    assert(conversation.unreadCount == 0, "the clicked partner's whispers are read")
    assert(refreshCount() == 1, "the window refreshes once")
  end)

  check("test_tab_click_for_other_partner_leaves_unread", function()
    local runtime = newRuntime(2)
    local captured = install(runtime)
    captured.fn(tab(4), "LeftButton")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 2, "another partner's tab leaves Thrall unread")
  end)

  check("test_right_click_does_nothing", function()
    local runtime, refreshCount = newRuntime(2)
    local captured = install(runtime)
    captured.fn(tab(3), "RightButton")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 2, "right-click is not reading")
    assert(refreshCount() == 0, "no refresh")
  end)

  check("test_tab_click_without_button_marks_read", function()
    local runtime = newRuntime(2)
    local captured = install(runtime)
    captured.fn(tab(3), nil)
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 0, "a click with no button counts as a left click")
  end)

  check("test_tab_click_while_hiding_whispers_does_nothing", function()
    local runtime, refreshCount = newRuntime(2)
    runtime.accountState = { settings = { hideFromDefaultChat = true } }
    local captured = install(runtime)
    captured.fn(tab(3), "LeftButton")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 2, "whispers hidden from game chat stay unread")
    assert(refreshCount() == 0, "no refresh")
  end)

  check("test_tab_click_with_whispers_shown_marks_read", function()
    local runtime = newRuntime(2)
    runtime.accountState = { settings = { hideFromDefaultChat = false } }
    local captured = install(runtime)
    captured.fn(tab(3), "LeftButton")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 0, "whispers shown in game chat are read on a tab click")
  end)

  check("test_no_hook_when_function_missing", function()
    rawset(_G, "FCF_Tab_OnClick", nil)
    local runtime = newRuntime(2)
    local captured = install(runtime)
    assert(captured.installs == 0, "nothing to hook on a client without FCF_Tab_OnClick")
  end)

  check("test_suspended_tab_click_does_nothing", function()
    local runtime = newRuntime(2)
    local captured = install(runtime, function()
      return true
    end)
    captured.fn(tab(3), "LeftButton")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 2, "suspended addon marks nothing")
  end)

  check("test_competitive_tab_click_does_nothing", function()
    local runtime = newRuntime(2)
    runtime.isCompetitiveContent = function()
      return true
    end
    local captured = install(runtime)
    captured.fn(tab(3), "LeftButton")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 2, "competitive content marks nothing")
  end)

  check("test_mark_on_read_conversation_skips_refresh", function()
    local runtime, refreshCount = newRuntime(0)
    local marked = GameChatRead.Mark(runtime, "wow::WOW::thrall")
    assert(marked == false, "nothing unread, nothing marked")
    assert(refreshCount() == 0, "no refresh for an already read conversation")
  end)

  check("test_mark_clears_unread_mention_and_refreshes", function()
    local runtime, refreshCount = newRuntime(0)
    runtime.store.conversations["wow::WOW::thrall"].hasUnreadMention = true
    local marked = GameChatRead.Mark(runtime, "wow::WOW::thrall")
    assert(marked == true and runtime.store.conversations["wow::WOW::thrall"].hasUnreadMention == nil, "mention cleared")
    assert(refreshCount() == 1, "refreshes")
  end)

  check("test_mark_unknown_conversation_creates_nothing", function()
    local runtime, refreshCount = newRuntime(0)
    assert(GameChatRead.Mark(runtime, "wow::WOW::sylvanas") == false, "unknown key is not marked")
    assert(GameChatRead.Mark(runtime, nil) == false, "nil key is not marked")
    assert(runtime.store.conversations["wow::WOW::sylvanas"] == nil, "no conversation is created")
    assert(refreshCount() == 0, "no refresh")
  end)

  check("test_tab_click_without_frame_does_nothing", function()
    rawset(_G, "ChatFrame3", nil)
    local runtime, refreshCount = newRuntime(2)
    local captured = install(runtime)
    local ok = pcall(captured.fn, tab(3), "LeftButton")
    assert(ok, "a tab with no chat frame is not an error")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 2, "nothing marked")
    assert(refreshCount() == 0, "no refresh")
  end)

  check("test_tab_without_get_id_does_nothing", function()
    local runtime = newRuntime(2)
    local captured = install(runtime)
    local ok = pcall(captured.fn, {}, "LeftButton")
    assert(ok, "a tab that cannot name its frame is not an error")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 2, "nothing marked")
  end)
end
