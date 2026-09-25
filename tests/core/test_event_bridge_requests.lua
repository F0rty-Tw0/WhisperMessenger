local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- Requests inbox, end to end through the live whisper route: a stranger's
-- first whisper is flagged and never alerts; replying accepts it.

local function whisper(runtime, eventName, name, guid)
  EventBridge.RouteLiveEvent(
    runtime,
    nil,
    eventName or "CHAT_MSG_WHISPER",
    "hello",
    name or "Stranger-Realm",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    1,
    guid or "Player-1-ABC"
  )
end

local function onlyConversation(runtime)
  local _, conversation = next(runtime.store.conversations)
  return conversation
end

return function()
  local flashes, sounds, autoOpens

  local function setup(settings)
    flashes, sounds, autoOpens = 0, 0, 0
    rawset(_G, "FlashClientIcon", function()
      flashes = flashes + 1
    end)
    rawset(_G, "PlaySound", function()
      sounds = sounds + 1
    end)
    rawset(_G, "InCombatLockdown", function()
      return false
    end)
    rawset(_G, "IsGuildMember", function()
      return false
    end)
    rawset(_G, "UnitInParty", function()
      return false
    end)
    rawset(_G, "UnitInRaid", function()
      return nil
    end)
    _G.C_Timer = { After = function() end }
    return {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      friendListApi = {
        IsFriend = function()
          return false
        end,
      },
      bnetApi = {
        GetGameAccountInfoByGUID = function()
          return nil
        end,
      },
      accountState = { settings = settings },
      onAutoOpen = function()
        autoOpens = autoOpens + 1
      end,
    }
  end

  -- test_stranger_whisper_becomes_silent_request
  do
    local runtime = setup({ requestsInbox = true, playSoundOnWhisper = true, autoOpenIncoming = true })
    whisper(runtime)
    local conversation = onlyConversation(runtime)
    assert(conversation.request == true, "stranger's first whisper is a request")
    assert(flashes == 0 and sounds == 0 and autoOpens == 0, "a request never alerts")
    assert(conversation.unreadCount == 1, "a request still counts unread on its own row")
  end

  -- test_setting_off_is_unchanged
  do
    local runtime = setup({ playSoundOnWhisper = true })
    whisper(runtime)
    assert(onlyConversation(runtime).request == nil, "setting off: no request")
    assert(flashes == 1 and sounds == 1, "setting off: alerts as before")
  end

  -- test_existing_conversation_is_not_reclassified
  do
    local runtime = setup({})
    whisper(runtime)
    runtime.accountState.settings.requestsInbox = true
    whisper(runtime)
    assert(onlyConversation(runtime).request == nil, "classification happens only at creation")
  end

  -- test_battle_net_whisper_is_never_a_request
  do
    local runtime = setup({ requestsInbox = true })
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_BN_WHISPER", "hi", "Friend#1", "", "", "", "", "", "", "", "", 1, nil, 42)
    assert(onlyConversation(runtime).request == nil, "Battle.net whisper is never a request")
  end

  -- test_replying_accepts_the_request
  do
    local runtime = setup({ requestsInbox = true })
    whisper(runtime)
    whisper(runtime, "CHAT_MSG_WHISPER_INFORM")
    assert(onlyConversation(runtime).request == nil, "sending a message accepts the request")
  end

  -- test_outgoing_first_is_not_a_request
  do
    local runtime = setup({ requestsInbox = true })
    whisper(runtime, "CHAT_MSG_WHISPER_INFORM")
    whisper(runtime)
    assert(onlyConversation(runtime).request == nil, "a conversation you started is not a request")
  end

  for _, name in ipairs({ "FlashClientIcon", "PlaySound", "InCombatLockdown", "IsGuildMember", "UnitInParty", "UnitInRaid" }) do
    rawset(_G, name, nil)
  end
  _G.C_Timer = nil
end
