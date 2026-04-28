-- When the user has the Groups tab selected and sends a whisper, the messenger
-- should switch to the Whispers tab (via the outgoing auto-open path) so the
-- new conversation is visible instead of hiding behind a group row.

local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- lupa harness runs Lua 5.1 where table.unpack doesn't exist.
local unpackArgs = table.unpack or unpack

local WHISPER_INFORM_ARGS = {
  "hello",
  "Arthas-Area52",
  "",
  "",
  "Arthas-Area52",
  "",
  0,
  0,
  "",
  0,
  123,
  "Player-1-00000001",
  0,
  false,
}

local function stubGlobals()
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "IsInGroup", function()
    return true
  end)
  rawset(_G, "time", function()
    return 1000
  end)
end

local function makeRuntime(tabMode)
  return {
    store = { conversations = {}, config = {} },
    now = function()
      return 1000
    end,
    accountState = {
      settings = { autoOpenIncoming = true, autoOpenOutgoing = true, playSoundOnWhisper = false },
    },
    localProfileId = "me",
    activeConversationKey = "PARTY::1",
    availabilityByGUID = {},
    pendingOutgoing = {},
    window = {
      getTabMode = function()
        return tabMode
      end,
    },
  }
end

return function()
  -- test_outgoing_whisper_on_groups_tab_fires_auto_open_outgoing
  do
    stubGlobals()
    local outgoingCalls = {}
    local runtime = makeRuntime("groups")
    runtime.onAutoOpenOutgoing = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER_INFORM", unpackArgs(WHISPER_INFORM_ARGS))

    assert(#outgoingCalls == 1, "expected onAutoOpenOutgoing to fire when user sends a whisper from the Groups tab; got " .. #outgoingCalls)
  end

  -- test_outgoing_whisper_on_whispers_tab_still_fires_auto_open_outgoing
  do
    stubGlobals()
    local outgoingCalls = {}
    local runtime = makeRuntime("whispers")
    runtime.onAutoOpenOutgoing = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER_INFORM", unpackArgs(WHISPER_INFORM_ARGS))

    assert(#outgoingCalls == 1, "regression: outgoing auto-open must still fire on the Whispers tab; got " .. #outgoingCalls)
  end
end
