local Store = require("WhisperMessenger.Model.ConversationStore")
local Router = require("WhisperMessenger.Core.EventRouter")
local RuntimeBindings = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RuntimeBindings")

-- A shown window whose selected chat is "Arthas"; `env.panesShown` is what the
-- window says about its chat panes (a panel or the options pane hide them).
local function build()
  local env = { panesShown = true, visible = true }
  local window = {
    isConversationPaneShown = function()
      return env.panesShown
    end,
  }
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
  }
  RuntimeBindings.Apply({
    runtime = state,
    controller = {},
    getWindow = function()
      return window
    end,
    isWindowVisible = function()
      return env.visible
    end,
  })
  env.state = state
  env.whisper = function(lineID)
    local conversation = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "hello " .. lineID,
      playerName = "Arthas-Area52",
      guid = "Player-1-00000001",
      lineID = lineID,
    })
    return conversation
  end
  -- The first whisper creates the chat and selects it.
  local first = env.whisper(1)
  state.activeConversationKey = first.conversationKey
  first.unreadCount = 0
  env.conversation = first
  return env
end

return function()
  -- test_whisper_to_the_open_chat_is_read_at_once
  do
    local env = build()
    env.whisper(2)
    assert(env.conversation.unreadCount == 0, "chat on screen: read, got " .. env.conversation.unreadCount)
  end

  -- test_whisper_to_the_chat_under_a_panel_or_options_stays_unread
  do
    local env = build()
    env.panesShown = false
    env.whisper(2)
    env.whisper(3)
    assert(env.conversation.unreadCount == 2, "covered chat: unread, got " .. env.conversation.unreadCount)
  end
end
