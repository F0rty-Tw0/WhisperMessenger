local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- Whispers that alert hand their conversation to the pop-up cards; muted
-- chats and outgoing whispers never do.

local function whisper(runtime, eventName, text)
  EventBridge.RouteLiveEvent(
    runtime,
    nil,
    eventName or "CHAT_MSG_WHISPER",
    text or "hello",
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
end

return function()
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  _G.C_Timer = { After = function() end }

  local function setup()
    local toasted = {}
    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      accountState = { settings = {} },
      showWhisperToast = function(conversationKey)
        toasted[#toasted + 1] = conversationKey
      end,
    }
    return runtime, toasted
  end

  -- test_incoming_whisper_is_offered_to_the_cards
  do
    local runtime, toasted = setup()
    whisper(runtime)
    local key = next(runtime.store.conversations)
    assert(#toasted == 1 and toasted[1] == key, "the whisper's conversation reaches the cards")
  end

  -- test_second_line_inside_the_alert_throttle_still_updates_the_card
  do
    local runtime, toasted = setup()
    whisper(runtime, nil, "one")
    whisper(runtime, nil, "two")
    assert(#toasted == 2, "a quick second line still updates its card, got " .. #toasted)
  end

  -- test_muted_conversation_pops_no_card
  do
    local runtime, toasted = setup()
    whisper(runtime)
    local _, conversation = next(runtime.store.conversations)
    conversation.muted = true
    whisper(runtime)
    assert(#toasted == 1, "a muted chat never pops a card, got " .. #toasted)
  end

  -- test_outgoing_whisper_pops_no_card
  do
    local runtime, toasted = setup()
    whisper(runtime, "CHAT_MSG_WHISPER_INFORM")
    assert(#toasted == 0, "outgoing whispers never pop a card")
  end

  rawset(_G, "InCombatLockdown", nil)
  _G.C_Timer = nil
end
