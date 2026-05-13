-- Regression: WoW Classic's character-whisper protocol does not carry quest
-- hyperlinks. When our addon sends a real `|Hquest:...|h[Name]|h|r` link via
-- SendChatMessage, the `CHAT_MSG_WHISPER_INFORM` echo can come back as plain
-- text `[Name (id)]`. The recorded outgoing message then renders as plain
-- text in the bubble even though we sent a real link.
--
-- BNet (`CHAT_MSG_BN_WHISPER_INFORM`) is unaffected — that protocol preserves
-- the hyperlink format end-to-end.
--
-- Fix: rewrite plain `[Name (id)]` segments inside `buildMessage` so the
-- conversation store always holds a clickable link, regardless of which
-- channel echoed the outgoing message.

local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")

local function makeState()
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    queue = Queue.New(),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 1000
    end,
    isChatMessagingLocked = function()
      return false
    end,
  }
end

local function firstConversation(state)
  for _, conv in pairs(state.store.conversations) do
    return conv
  end
  return nil
end

return function()
  -- Character whisper INFORM with plain-text quest link rewritten to a real
  -- hyperlink in the stored message.
  local state = makeState()
  Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
    text = "check this [Apprentice's Duties (471)] please",
    playerName = "Thrall-Nagrand",
    lineID = 301,
    guid = "Player-1-0001",
  })

  local conversation = firstConversation(state)
  assert(conversation ~= nil, "expected conversation recorded for character whisper inform")
  local message = conversation.messages[1]
  assert(message ~= nil, "expected outgoing message stored")
  local expected = "check this |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r please"
  assert(message.text == expected, "expected plain-text quest in echo to be rewritten to hyperlink, got: " .. tostring(message.text))

  -- Incoming character whisper containing plain-text quest link is also
  -- rewritten so the bubble renders a clickable link.
  state = makeState()
  Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
    text = "help with [Apprentice's Duties (471)]?",
    playerName = "Sylvanas-Silvermoon",
    lineID = 302,
    guid = "Player-1-0002",
  })

  local incomingConversation = firstConversation(state)
  assert(incomingConversation ~= nil, "expected conversation recorded for incoming whisper")
  local incomingMessage = incomingConversation.messages[1]
  local incomingExpected = "help with |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r?"
  assert(incomingMessage.text == incomingExpected, "expected incoming plain-text quest to be rewritten, got: " .. tostring(incomingMessage.text))

  -- WoW Classic's character-whisper server can strip a real outgoing quest
  -- hyperlink down to a bare label ("Cutting Teeth") with no brackets or id,
  -- so the pattern-rewrite alone can't recover it. When a matching pending
  -- send exists, the bubble must use OUR pending text (the rich hyperlink we
  -- tried to send) instead of the stripped echo.
  state = makeState()
  local pendingHyperlink = "look at |cffffff00|Hquest:788:0|h[Cutting Teeth]|h|r"
  Router.RecordPendingSend(state, {
    channel = "WOW",
    target = "Selvaggio",
    displayName = "Selvaggio",
    guid = "Player-1-0003",
  }, pendingHyperlink)
  Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
    text = "look at Cutting Teeth",
    playerName = "Selvaggio",
    lineID = 304,
    guid = "Player-1-0003",
  })
  local strippedConv = firstConversation(state)
  assert(strippedConv ~= nil, "expected stripped-echo conversation recorded")
  local strippedMessage = strippedConv.messages[1]
  assert(
    strippedMessage.text == pendingHyperlink,
    "expected bubble to use pending hyperlink when server stripped the echo, got: " .. tostring(strippedMessage.text)
  )

  -- Two successive stripped-echo sends must each surface their OWN pending
  -- text. A stale entry left behind by an earlier strip would cause the
  -- second bubble to echo the first quest's link.
  state = makeState()
  local firstLink = "first |cffffff00|Hquest:788:0|h[Cutting Teeth]|h|r"
  Router.RecordPendingSend(state, {
    channel = "WOW",
    target = "Selvaggio",
    displayName = "Selvaggio",
    guid = "Player-1-0003",
  }, firstLink)
  Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
    text = "first Cutting Teeth",
    playerName = "Selvaggio",
    lineID = 401,
    guid = "Player-1-0003",
  })

  local secondLink = "second |cffffff00|Hquest:1485:0|h[Vile Familiars]|h|r"
  Router.RecordPendingSend(state, {
    channel = "WOW",
    target = "Selvaggio",
    displayName = "Selvaggio",
    guid = "Player-1-0003",
  }, secondLink)
  Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
    text = "second Vile Familiars",
    playerName = "Selvaggio",
    lineID = 402,
    guid = "Player-1-0003",
  })

  local successiveConv = firstConversation(state)
  assert(successiveConv ~= nil, "expected conversation recorded for successive sends")
  assert(#successiveConv.messages == 2, "expected exactly two messages, got: " .. tostring(#successiveConv.messages))
  assert(successiveConv.messages[1].text == firstLink, "first bubble should keep first link, got: " .. tostring(successiveConv.messages[1].text))
  assert(
    successiveConv.messages[2].text == secondLink,
    "second bubble should use second link (not stale first), got: " .. tostring(successiveConv.messages[2].text)
  )

  -- Already-hyperlinked text passes through untouched (idempotent).
  state = makeState()
  local alreadyLinked = "look at |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
  Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER_INFORM", {
    text = alreadyLinked,
    playerName = "Friend",
    lineID = 303,
    channel = "BN",
    bnetAccountID = 77,
    accountInfo = { battleTag = "Friend#1234" },
  })
  local bnConversation = firstConversation(state)
  assert(bnConversation ~= nil, "expected BN conversation recorded")
  assert(
    bnConversation.messages[1].text == alreadyLinked,
    "expected already-hyperlinked text unchanged, got: " .. tostring(bnConversation.messages[1].text)
  )
end
