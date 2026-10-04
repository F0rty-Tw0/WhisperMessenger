local Store = require("WhisperMessenger.Model.ConversationStore")

local Router = require("WhisperMessenger.Core.EventRouter")
local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")

return function()
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
  }

  -- When normalizeName cannot process a tainted name it returns "".
  -- Passing "" as playerName simulates the effective result of a fully-tainted
  -- whisper event where the name degrades to empty after pcall fallbacks.
  -- The router should detect this degenerate contact and drop the event.
  local result = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
    text = "hello",
    playerName = "",
    lineID = 999,
    guid = "Player-1-0ABC",
    playerInfo = {},
  })

  assert(result == nil, "expected nil for degenerate empty-name event, got: " .. tostring(result))

  -- No degenerate conversation should be stored
  local degenerateConv = state.store.conversations["wow::WOW::"]
  assert(degenerateConv == nil, "should not store conversation with degenerate key")

  -- test_whisper_from_ignored_sender_creates_no_conversation
  do
    state.accountState = { filters = { ignored = {}, rules = {} } }
    IgnoreList.Add(state.accountState.filters, "Spammer-Realm", { now = 1 })
    local dropped = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "cheap gold",
      playerName = "Spammer-Realm",
      lineID = 1000,
      guid = "Player-1-0DEF",
      playerInfo = {},
    })
    assert(dropped == nil, "a whisper from an ignored sender is dropped")
    assert(next(state.store.conversations) == nil, "no conversation is created for an ignored sender")
  end
end
