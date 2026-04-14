local FakeUI = require("tests.helpers.fake_ui")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

return function()
  local savedSetLastTell = _G.ChatEdit_SetLastTellTarget
  local savedGetCVar = _G.GetCVar
  local savedSetCVar = _G.SetCVar

  rawset(_G, "GetCVar", function()
    return "1"
  end)
  rawset(_G, "SetCVar", function() end)

  -- -----------------------------------------------------------------------
  -- test_does_not_touch_blizzard_reply_target_for_character_whisper
  -- -----------------------------------------------------------------------
  do
    local setLastTellCalled = false
    rawset(_G, "ChatEdit_SetLastTellTarget", function()
      setLastTellCalled = true
    end)

    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      accountState = { settings = { hideFromDefaultChat = true } },
      isMythicLockdown = function()
        return false
      end,
      isCompetitiveContent = function()
        return false
      end,
    }

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER",
      "hello",
      "Arthas",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      1,
      "Player-1-ABC"
    )

    assert(
      setLastTellCalled == false,
      "character whisper should not call ChatEdit_SetLastTellTarget; rely on tracked reply key instead"
    )
    assert(
      runtime.lastIncomingWhisperKey == "wow::WOW::arthas",
      "expected character whisper to track the exact conversation key for ReplyTell routing"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_does_not_touch_blizzard_reply_target_for_bnet_whisper
  -- -----------------------------------------------------------------------
  do
    local setLastTellCalled = false
    rawset(_G, "ChatEdit_SetLastTellTarget", function()
      setLastTellCalled = true
    end)

    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      bnetApi = {},
      playerInfoByGUID = {},
      accountState = { settings = { hideFromDefaultChat = true } },
      isMythicLockdown = function()
        return false
      end,
      isCompetitiveContent = function()
        return false
      end,
    }

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_BN_WHISPER",
      "hello",
      "Friend",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      2,
      "Player-2-DEF",
      42
    )

    assert(
      setLastTellCalled == false,
      "bn whisper should not call ChatEdit_SetLastTellTarget; rely on tracked reply key instead"
    )
    assert(
      runtime.lastIncomingWhisperKey == "bnet::BN::42",
      "expected BN whisper to track the exact conversation key for ReplyTell routing"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_does_not_set_reply_target_when_hide_disabled
  -- -----------------------------------------------------------------------
  do
    local setLastTellCalled = false
    rawset(_G, "ChatEdit_SetLastTellTarget", function()
      setLastTellCalled = true
    end)

    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      accountState = { settings = { hideFromDefaultChat = false } },
    }

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER",
      "hello",
      "Arthas",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      1,
      "Player-1-ABC"
    )

    assert(setLastTellCalled == false, "test_no_reply_target_when_hide_disabled: should not call SetLastTellTarget")
  end

  -- -----------------------------------------------------------------------
  -- test_does_not_set_reply_target_for_outgoing
  -- -----------------------------------------------------------------------
  do
    local setLastTellCalled = false
    rawset(_G, "ChatEdit_SetLastTellTarget", function()
      setLastTellCalled = true
    end)

    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      accountState = { settings = { hideFromDefaultChat = true } },
    }

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER_INFORM",
      "hello",
      "Arthas",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      1,
      "Player-1-ABC"
    )

    assert(
      setLastTellCalled == false,
      "test_no_reply_target_for_outgoing: should not call SetLastTellTarget for outgoing"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_does_not_set_reply_target_when_suspended
  -- -----------------------------------------------------------------------
  do
    local setLastTellCalled = false
    rawset(_G, "ChatEdit_SetLastTellTarget", function()
      setLastTellCalled = true
    end)

    _G._wmSuspended = true

    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      accountState = { settings = { hideFromDefaultChat = true } },
    }

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER",
      "hello",
      "Arthas",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      1,
      "Player-1-ABC"
    )

    assert(
      setLastTellCalled == false,
      "test_no_reply_target_when_suspended: should not call SetLastTellTarget when addon is suspended"
    )
    _G._wmSuspended = nil
  end

  rawset(_G, "ChatEdit_SetLastTellTarget", savedSetLastTell)
  rawset(_G, "GetCVar", savedGetCVar)
  rawset(_G, "SetCVar", savedSetCVar)
end
