-- onUnreadChanged and GetUnreadCount through the real runtime: ingest, reading
-- a chat and Mark all read each tell the panel once, on the next frame.
local PublicApiEnv = require("tests.helpers.public_api_env")
local FakeChatLines = require("tests.helpers.fake_chat_lines")
local Router = require("WhisperMessenger.Core.EventRouter")

local BOB = "wow::WOW::bob-area52"
local JAINA = "wow::WOW::jaina-area52"

local function noop() end

local function no()
  return false
end

local STRANGER_GLOBALS = { "IsGuildMember", "UnitInParty", "UnitInRaid" }

return function()
  local savedRealm = rawget(_G, "GetNormalizedRealmName")
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  local savedGlobals = {}
  for _, name in ipairs(STRANGER_GLOBALS) do
    savedGlobals[name] = rawget(_G, name)
    rawset(_G, name, no)
  end

  local runtime, api = PublicApiEnv.Initialize({ requestsInbox = true })
  -- Every check MessageRequests asks must say "not known", or no request is flagged.
  runtime.friendListApi = { IsFriend = no }
  runtime.bnetApi = {
    GetGameAccountInfoByGUID = function()
      return nil
    end,
  }

  -- C_Timer is the shared fake table; DeferAfter replaces its After.
  local timer = rawget(_G, "C_Timer")
  local savedAfter = timer and timer.After
  FakeChatLines.DeferAfter()
  local flush = FakeChatLines.FlushAfter

  local calls = 0
  assert(api.RegisterPanel("t", {
    title = "T",
    onShow = noop,
    onUnreadChanged = function()
      calls = calls + 1
    end,
  }) == true, "panel registered")

  -- Mirrors EventBridge: the router never refreshes on its own.
  local function whisper(name, lineID, guid)
    local result = Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", { text = "hi", playerName = name, guid = guid, lineID = lineID })
    runtime.refreshWindow(result and result.conversationKey)
  end

  -- Prime the baseline.
  runtime.updateIconSurfaces()
  flush()
  calls = 0

  -- test_stranger_whisper_into_requests_fires_once
  do
    whisper("Bob-Area52", 9101, "Player-60-0000B0B1")
    assert(calls == 0, "deferred")
    flush()
    assert(calls == 1, "got " .. calls)
    assert(api.GetUnreadCount("Bob-Area52") == 1, "got " .. api.GetUnreadCount("Bob-Area52"))
    assert(runtime.accountState.conversations[BOB].request == true, "landed in Requests")
  end

  -- test_muted_chat_whisper_counts_raw
  do
    whisper("Jaina-Area52", 9102, "Player-60-0000JA01")
    flush()
    local conversation = runtime.accountState.conversations[JAINA]
    conversation.request = nil
    conversation.muted = true
    calls = 0
    whisper("Jaina-Area52", 9103, "Player-60-0000JA01")
    flush()
    assert(calls == 1, "got " .. calls)
    assert(api.GetUnreadCount("Jaina-Area52") == 2, "got " .. api.GetUnreadCount("Jaina-Area52"))
  end

  -- test_reading_the_chat_fires_once
  do
    calls = 0
    assert(api.OpenConversation("Bob-Area52") == true, "opened")
    flush()
    assert(calls == 1, "got " .. calls)
    assert(api.GetUnreadCount("Bob-Area52") == 0, "got " .. api.GetUnreadCount("Bob-Area52"))
  end

  -- test_mark_all_read_fires_once
  do
    -- Not Bob: a whisper into the open chat never counts as unread.
    whisper("Cara-Area52", 9104, "Player-60-0000CA01")
    flush()
    assert(api.GetUnreadCount("Cara-Area52") == 1, "Cara unread before Mark all read")
    calls = 0
    local button = runtime.window.markAllReadButton
    button:GetScript("OnClick")(button)
    flush()
    assert(calls == 1, "got " .. calls)
    for _, name in ipairs({ "Bob-Area52", "Jaina-Area52", "Cara-Area52" }) do
      assert(api.GetUnreadCount(name) == 0, name .. " read, got " .. api.GetUnreadCount(name))
    end
  end

  -- test_no_change_no_call
  do
    calls = 0
    runtime.updateIconSurfaces()
    flush()
    assert(calls == 0, "got " .. calls)
  end

  if timer then
    timer.After = savedAfter
  end
  PublicApiEnv.Reset()
  for _, name in ipairs(STRANGER_GLOBALS) do
    rawset(_G, name, savedGlobals[name])
  end
  rawset(_G, "GetNormalizedRealmName", savedRealm)
end
