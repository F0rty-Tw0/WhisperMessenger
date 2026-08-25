local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageReactions = require("WhisperMessenger.Model.MessageReactions")
local Router = require("WhisperMessenger.Core.EventRouter")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")

local function newRuntime(nowRef)
  local store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 })
  local accountState = { settings = {}, conversations = store.conversations }
  return {
    localProfileId = "me",
    store = store,
    accountState = accountState,
    characterState = {},
    pendingOutgoing = {},
    sendStatusByConversation = {},
    availabilityByGUID = {},
    now = function()
      return nowRef.value
    end,
  }
end

local function putTarget(runtime, key, sentAt)
  runtime.store.conversations[key] = {
    conversationKey = key,
    displayName = "Arthas-Area52",
    channel = "WOW",
    messages = {
      { kind = "user", direction = "out", text = "Original", wireId = "target", sentAt = sentAt },
    },
    unreadCount = 0,
    lastPreview = "Original",
    lastActivityAt = sentAt,
  }
end

local function stageFallback(runtime, key, lineID)
  local fallback = Protocol.BuildFallback("heart", "set", "Original")
  local result = Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", {
    text = fallback,
    playerName = "Arthas-Area52",
    guid = "Player-1",
    lineID = lineID,
  })
  assert(result == nil, "fallback fixture should stage while metadata is missing")
  return fallback
end

local function callbacksFor(runtime)
  return WindowCallbacks.Create({
    runtime = runtime,
    accountState = runtime.accountState,
    characterState = runtime.characterState,
    defaultCharacterState = {},
    sendHandler = { HandleSend = function() end },
    reactionHandler = { HandleReact = function() end },
    tableUtils = {
      copyState = function(value)
        return value
      end,
    },
    refreshWindow = function() end,
  })
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil
  local key = "wow::WOW::arthas-area52"

  -- Removing one conversation cancels its staged expiry closure.
  do
    local now = { value = 100 }
    local runtime = newRuntime(now)
    putTarget(runtime, key, 90)
    stageFallback(runtime, key, 1)
    callbacksFor(runtime).onRemove({ conversationKey = key, displayName = "Arthas-Area52" })
    assert(runtime.store.conversations[key] == nil, "remove should delete conversation immediately")
    now.value = 115
    MessageReactions.Expire(runtime, now.value)
    assert(runtime.store.conversations[key] == nil, "expired staged fallback must not recreate removed conversation")
  end

  -- Clearing all chats cancels every staged expiry closure.
  do
    local now = { value = 200 }
    local runtime = newRuntime(now)
    putTarget(runtime, key, 190)
    stageFallback(runtime, key, 2)
    callbacksFor(runtime).onClearAllChats()
    assert(next(runtime.store.conversations) == nil, "clear all should delete conversations immediately")
    now.value = 215
    MessageReactions.Expire(runtime, now.value)
    assert(next(runtime.store.conversations) == nil, "expired staged fallback must not recreate cleared conversations")
  end

  -- Logout flushes delivered normal fallback into persisted history before save.
  do
    local now = { value = 300 }
    local runtime = newRuntime(now)
    putTarget(runtime, key, 290)
    runtime.store.conversations[key].messages[1]._pendingReaction = {
      token = 99,
      operation = "set",
      key = "heart",
      actorName = "Artio",
    }
    local fallback = stageFallback(runtime, key, 3)
    assert(#runtime.store.conversations[key].messages == 1, "staged fallback should not persist before logout")
    LifecycleHandlers.Handle({ runtime = runtime }, "PLAYER_LOGOUT", {
      trace = function() end,
    })
    local conversation = runtime.accountState.conversations[key]
    assert(conversation and #conversation.messages == 2, "logout should flush staged fallback into saved conversation")
    assert(conversation.messages[2].text == fallback, "logout flush should preserve readable delivered fallback")
    assert(conversation.unreadCount == 1, "logout flush should apply unread effect at actual degradation")
    assert(conversation.messages[1]._pendingReaction == nil, "logout should clear transient pending reaction before persistence")
  end

  _G.C_Timer = savedTimer
end
