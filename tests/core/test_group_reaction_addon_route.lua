local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local Router = require("WhisperMessenger.Core.EventRouter")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

return function()
  local now = 1900
  local key = "party::me::1::Party-0-current"
  local target = {
    kind = "user",
    direction = "out",
    channel = "PARTY",
    text = "route target",
    guid = "Player-me",
    playerName = "Me-Realm",
    wireId = "routewire",
  }
  local state = {
    localProfileId = "me",
    localPlayerGuid = "Player-me",
    groupPartyGUIDsByCategory = { [1] = "Party-0-current" },
    store = Store.New({ maxMessagesPerConversation = 20 }),
    pendingOutgoing = { sentinel = true },
    lastIncomingWhisperKey = "whisper-sentinel",
    now = function()
      return now
    end,
  }
  state.store.conversations[key] = { conversationKey = key, channel = "PARTY", messages = { target }, unreadCount = 0 }
  local fallback = Protocol.BuildGroupFallback("heart", "set", target.text)
  local operation = assert(Protocol.EncodeGroupReaction("set", "heart", target.wireId, target.text, fallback, target.guid, target.playerName))

  assert(
    Router.HandleEvent(state, "CHAT_MSG_ADDON", { prefix = "WMRX", channel = "PARTY", playerName = "Reactor-Realm", text = operation }) == nil,
    "group addon metadata should route without creating whisper state"
  )
  GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
    text = fallback,
    playerName = "Reactor-Realm",
    guid = "Player-reactor",
    lineID = 1901,
  })
  assert(target.reaction and target.reaction.key == "heart", "routed group addon metadata should convert its fallback")
  assert(state.pendingOutgoing.sentinel == true and state.lastIncomingWhisperKey == "whisper-sentinel", "group addon must not touch whisper state")

  local autoOpens = 0
  state.accountState = { settings = { autoOpenIncoming = true } }
  state.onAutoOpen = function()
    autoOpens = autoOpens + 1
  end
  EventBridge.RouteLiveEvent(state, function() end, "CHAT_MSG_ADDON", "WMRX", operation, "PARTY", "Reactor-Realm")
  assert(autoOpens == 0 and state.store.conversations[key] ~= nil, "group addon routing must not auto-open or create whisper state")
end
