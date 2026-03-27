local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")

return function()
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    queue = Queue.New(),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
    isChatMessagingLocked = function()
      return false
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
end
