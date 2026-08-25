local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageReactions = require("WhisperMessenger.Model.MessageReactions")
local Router = require("WhisperMessenger.Core.EventRouter")

local function newState(nowRef)
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return nowRef.value
    end,
  }
end

local function identityEvent(wireId, text)
  return {
    prefix = "WMRX",
    text = Protocol.EncodeIdentity(wireId, text),
    channel = "WHISPER",
    playerName = "Arthas-Area52",
  }
end

local function whisperEvent(text, lineID)
  return {
    text = text,
    playerName = "Arthas-Area52",
    guid = "Player-1",
    lineID = lineID,
  }
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil
  local key = "wow::WOW::arthas-area52"
  local fallbackShaped = Protocol.BuildFallback("heart", "set", "ordinary quoted text")

  -- Identity metadata before two identical fallback-shaped ordinary whispers pairs FIFO.
  do
    local now = { value = 100 }
    local state = newState(now)
    Router.HandleEvent(state, "CHAT_MSG_ADDON", identityEvent("metafirst1", fallbackShaped))
    Router.HandleEvent(state, "CHAT_MSG_ADDON", identityEvent("metafirst2", fallbackShaped))
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent(fallbackShaped, 1))
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent(fallbackShaped, 2))
    assert(state.store.conversations[key] == nil, "possible controls should remain staged during TTL")
    now.value = 115
    MessageReactions.Expire(state, now.value)
    local conversation = state.store.conversations[key]
    assert(conversation and #conversation.messages == 2, "both ordinary fallback-shaped whispers should degrade into history")
    assert(conversation.messages[1].wireId == "metafirst1", "first duplicate should retain first metadata wire ID")
    assert(conversation.messages[2].wireId == "metafirst2", "second duplicate should retain second metadata wire ID")
  end

  -- Two identical fallback-shaped messages before identity metadata also pair FIFO.
  do
    local now = { value = 200 }
    local state = newState(now)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent(fallbackShaped, 3))
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent(fallbackShaped, 4))
    Router.HandleEvent(state, "CHAT_MSG_ADDON", identityEvent("messagefirst1", fallbackShaped))
    Router.HandleEvent(state, "CHAT_MSG_ADDON", identityEvent("messagefirst2", fallbackShaped))
    now.value = 215
    MessageReactions.Expire(state, now.value)
    local conversation = state.store.conversations[key]
    assert(conversation and #conversation.messages == 2, "message-first ordinary controls should degrade into history")
    assert(conversation.messages[1].wireId == "messagefirst1", "first staged duplicate should receive first later wire ID")
    assert(conversation.messages[2].wireId == "messagefirst2", "second staged duplicate should receive second later wire ID")
  end

  -- A real reaction conversion discards the temporary identity candidate.
  do
    local now = { value = 300 }
    local state = newState(now)
    local target = { kind = "user", direction = "out", text = "real target", wireId = "realtarget", sentAt = 290 }
    state.store.conversations[key] = {
      conversationKey = key,
      displayName = "Arthas-Area52",
      channel = "WOW",
      messages = { target },
      unreadCount = 0,
      lastPreview = target.text,
      lastActivityAt = target.sentAt,
    }
    local realFallback = Protocol.BuildFallback("wow", "set", target.text)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent(realFallback, 5))
    local identityQueue = state.messageReactionRuntime and state.messageReactionRuntime.identityMessages["wow::WOW::arthas-area52"]
    assert(identityQueue and #identityQueue == 1, "possible control should stage one identity candidate")
    Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = Protocol.EncodeReaction("set", "wow", target.wireId, target.text, realFallback),
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    identityQueue = state.messageReactionRuntime and state.messageReactionRuntime.identityMessages["wow::WOW::arthas-area52"]
    assert(identityQueue == nil or #identityQueue == 0, "successful conversion should discard control identity candidate")
    assert(target.reaction and target.reaction.key == "wow", "real reaction should still convert")
    assert(#state.store.conversations[key].messages == 1, "converted control should not enter history")
  end

  _G.C_Timer = savedTimer
end
