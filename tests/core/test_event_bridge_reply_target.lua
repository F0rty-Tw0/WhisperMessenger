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
  -- test_sets_reply_target_for_character_whisper_when_hide_enabled
  -- -----------------------------------------------------------------------
  do
    local lastTarget, lastType
    rawset(_G, "ChatEdit_SetLastTellTarget", function(target, chatType)
      lastTarget = target
      lastType = chatType
    end)

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

    assert(lastTarget == "Arthas", "test_sets_reply_target_character: expected 'Arthas', got " .. tostring(lastTarget))
    assert(lastType == "WHISPER", "test_sets_reply_target_character: expected 'WHISPER', got " .. tostring(lastType))
  end

  -- -----------------------------------------------------------------------
  -- test_sets_reply_target_for_bnet_whisper_when_hide_enabled
  -- -----------------------------------------------------------------------
  do
    local lastTarget, lastType
    rawset(_G, "ChatEdit_SetLastTellTarget", function(target, chatType)
      lastTarget = target
      lastType = chatType
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

    assert(lastTarget == "Friend", "test_sets_reply_target_bnet: expected 'Friend', got " .. tostring(lastTarget))
    assert(lastType == "BN_WHISPER", "test_sets_reply_target_bnet: expected 'BN_WHISPER', got " .. tostring(lastType))
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
