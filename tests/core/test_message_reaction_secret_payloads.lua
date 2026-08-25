local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local Router = require("WhisperMessenger.Core.EventRouter")
local QuestLinkClassic = require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")

local function newState()
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
  }
end

return function()
  local savedDetector = Router._isSecretString
  local savedDecode = Protocol.Decode
  local savedRewrite = QuestLinkClassic.Rewrite
  local savedCanonicalize = QuestLinkClassic.CanonicalizeForTransport
  local decodeCalls, rewriteCalls, canonicalizeCalls = 0, 0, 0

  Router._isSecretString = function(value)
    return value == "SECRET"
  end
  Protocol.Decode = function(payload)
    decodeCalls = decodeCalls + 1
    return savedDecode(payload)
  end
  QuestLinkClassic.Rewrite = function(text)
    rewriteCalls = rewriteCalls + 1
    return savedRewrite(text)
  end
  QuestLinkClassic.CanonicalizeForTransport = function(text)
    canonicalizeCalls = canonicalizeCalls + 1
    return savedCanonicalize(text)
  end

  -- Secret WMRX payload is rejected before protocol decode or sender queue indexing.
  do
    local state = newState()
    local result = Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = "SECRET",
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    assert(result == nil, "secret WMRX payload should be ignored")
    assert(decodeCalls == 0, "secret WMRX payload must be rejected before Decode")
    assert(state.messageReactionRuntime == nil, "secret WMRX payload must not create sender queues")
  end

  -- Secret normal whisper is rejected before rewrite, canonicalization, fingerprint, or storage.
  do
    local state = newState()
    local result = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "SECRET",
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 1,
    })
    assert(result == nil, "secret normal whisper should be ignored")
    assert(rewriteCalls == 0 and canonicalizeCalls == 0, "secret normal whisper must be rejected before text processing")
    assert(next(state.store.conversations) == nil, "secret normal whisper must not be stored")
    assert(state.messageReactionRuntime == nil, "secret normal whisper must not create reaction queues")
  end

  -- Secret sender identity is rejected before it can become a table key.
  do
    local state = newState()
    local result = Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = Protocol.EncodeIdentity("wire", "hello"),
      channel = "WHISPER",
      playerName = "SECRET",
    })
    assert(result == nil and decodeCalls == 0, "secret sender should be rejected before decode and queue indexing")
    assert(state.messageReactionRuntime == nil, "secret sender must not create keyed queues")
  end

  Router._isSecretString = savedDetector
  Protocol.Decode = savedDecode
  QuestLinkClassic.Rewrite = savedRewrite
  QuestLinkClassic.CanonicalizeForTransport = savedCanonicalize
end
