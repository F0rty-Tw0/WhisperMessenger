local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")

return function()
  local locked = true
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    queue = Queue.New(),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 500
    end,
    isChatMessagingLocked = function()
      return locked
    end,
  }

  local payload = {
    text = "queued whisper",
    playerName = "Arthas-Area52",
    lineID = 201,
    guid = "Player-3676-0ABCDEF0",
  }

  local result = Router.HandleEvent(state, "CHAT_MSG_WHISPER", payload)
  assert(result.queued == true)
  assert(#state.queue.items == 1)
  assert(next(state.store.conversations) == nil)

  locked = false
  local replayed = Router.ReplayQueued(state)
  assert(replayed == 1)

  local key = "me::WOW::arthas-area52"
  assert(state.store.conversations[key].messages[1].text == "queued whisper")
end
