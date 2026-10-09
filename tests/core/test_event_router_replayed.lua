local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageReactions = require("WhisperMessenger.Model.MessageReactions")
local PendingOutgoing = require("WhisperMessenger.Core.EventRouter.PendingOutgoing")
local Router = require("WhisperMessenger.Core.EventRouter")

local KEY = "wow::WOW::arthas-area52"

local function newRuntime(nowFn)
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = nowFn or function()
      return 1000
    end,
    accountState = { settings = {} },
    bnetApi = {},
  }
end

local function whisperPayload(text, lineID, replayedAt)
  return { text = text, playerName = "Arthas-Area52", guid = "Player-1", lineID = lineID, replayedAt = replayedAt }
end

local function seedIncomingAt(runtime, sentAt)
  Store.AppendIncoming(runtime.store, KEY, {
    id = "seed",
    direction = "in",
    kind = "user",
    text = "seed",
    sentAt = sentAt,
    lineID = 50,
    playerName = "Arthas-Area52",
  }, false)
  return runtime.store.conversations[KEY]
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil

  -- test_replayed_incoming_uses_replayed_at_and_lands_before_newer

  do
    local runtime = newRuntime()
    local conversation = seedIncomingAt(runtime, 900)
    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", whisperPayload("held during the key", 40, 800))
    assert(#conversation.messages == 2, "expected 2 messages, got " .. #conversation.messages)
    local first = conversation.messages[1]
    assert(first.text == "held during the key", "replayed whisper must land before the newer message")
    assert(first.sentAt == 800, "replayed whisper must keep its original time, got " .. tostring(first.sentAt))
  end

  -- test_replayed_inform_lands_as_outgoing_and_clears_request

  do
    local runtime = newRuntime()
    local conversation = seedIncomingAt(runtime, 900)
    conversation.request = { state = "pending" }
    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", whisperPayload("my held reply", 40, 800))
    local first = conversation.messages[1]
    assert(first.text == "my held reply" and first.direction == "out", "replayed inform must land as outgoing at its time")
    assert(first.sentAt == 800, "replayed inform must keep its original time")
    assert(conversation.request == nil, "replayed inform must accept the request")
  end

  -- test_replayed_inform_does_not_claim_pending_created_after_lift

  do
    local runtime = newRuntime()
    PendingOutgoing.Record(runtime, { channel = "WOW", displayName = "Arthas-Area52", guid = "Player-1" }, "same text")
    local _, meta = Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", whisperPayload("same text", 40, 800))
    local queue = runtime.pendingOutgoing[KEY]
    assert(queue ~= nil and #queue == 1, "pending send made after the lift must stay pending")
    assert(meta and meta.outgoingFromPendingSend ~= true, "replayed inform must not claim a newer pending send")
  end

  -- test_replayed_inform_older_than_unread_incoming_keeps_unread

  do
    local runtime = newRuntime()
    local conversation = seedIncomingAt(runtime, 1000)
    assert(conversation.unreadCount == 1, "setup: the live whisper must be unread")
    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", whisperPayload("my held reply", 40, 500))
    assert(conversation.unreadCount == 1, "an older replayed reply must not read a newer whisper, got " .. conversation.unreadCount)
  end

  -- test_replayed_inform_newer_than_everything_marks_read

  do
    local runtime = newRuntime()
    local conversation = seedIncomingAt(runtime, 900)
    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", whisperPayload("my held reply", 40, 950))
    assert(conversation.unreadCount == 0, "the newest replayed reply must mark read, got " .. conversation.unreadCount)
  end

  -- test_live_event_without_replayed_at_unchanged

  do
    local runtime = newRuntime()
    local conversation = seedIncomingAt(runtime, 900)
    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", whisperPayload("live", 60, nil))
    local last = conversation.messages[#conversation.messages]
    assert(last.text == "live" and last.sentAt == 1000, "live whisper must append at now()")
  end

  -- test_degrade_callback_captured_at_route_time

  do
    local now = 400
    local runtime = newRuntime(function()
      return now
    end)
    local target = { kind = "user", direction = "out", text = "Visible", wireId = "target3", sentAt = 390 }
    runtime.store.conversations[KEY] = {
      conversationKey = KEY,
      messages = { target },
      unreadCount = 0,
      lastPreview = target.text,
      lastActivityAt = target.sentAt,
    }
    local calledA, calledB = 0, 0
    local function setDegradeCallback(callback)
      runtime.onReactionFallbackDegraded = callback
    end
    setDegradeCallback(function()
      calledA = calledA + 1
    end)
    Router.HandleEvent(runtime, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = "2|R|S|heart|target3|12345678|12345678",
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", whisperPayload(Protocol.BuildFallback("sad", "set", target.text), 5, nil))
    setDegradeCallback(function()
      calledB = calledB + 1
    end)
    now = 415
    MessageReactions.Expire(runtime, now)
    assert(#runtime.store.conversations[KEY].messages == 2, "setup: fallback should have degraded into history")
    assert(calledA == 1, "callback present at route time must fire, got " .. calledA)
    assert(calledB == 0, "callback installed after routing must not fire")
  end

  _G.C_Timer = savedTimer
end
