local Store = require("WhisperMessenger.Model.ConversationStore")
local MessageReactions = require("WhisperMessenger.Model.MessageReactions")
local ReactionHandler = require("WhisperMessenger.Core.Bootstrap.ReactionHandler")
local Router = require("WhisperMessenger.Core.EventRouter")

local function newStore()
  return Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 })
end

local function newRuntime(nowRef, timers)
  local sent = {}
  local addons = {}
  local refreshes = 0
  local runtime = {
    localProfileId = "me",
    localPlayerName = "Artio",
    store = newStore(),
    pendingOutgoing = {},
    sendStatusByConversation = {},
    availabilityByGUID = {},
    now = function()
      return nowRef.value
    end,
    chatApi = {
      SendChatMessage = function(text)
        sent[#sent + 1] = text
      end,
      RegisterAddonMessagePrefix = function() end,
      SendAddonMessage = function(prefix, payload)
        if prefix == "WMRX" then
          addons[#addons + 1] = payload
        end
      end,
    },
    bnetApi = {},
  }
  local key = "wow::WOW::arthas-area52"
  local target = {
    kind = "user",
    direction = "in",
    text = "Pending target",
    wireId = "pendingtarget",
    sentAt = nowRef.value - 10,
    playerName = "Arthas-Area52",
  }
  runtime.store.conversations[key] = {
    conversationKey = key,
    displayName = "Arthas-Area52",
    channel = "WOW",
    messages = { target },
    unreadCount = 0,
    lastPreview = target.text,
    lastActivityAt = target.sentAt,
  }
  local contact = {
    conversationKey = key,
    displayName = "Arthas-Area52",
    guid = "Player-1",
    channel = "WOW",
  }
  local function refresh()
    refreshes = refreshes + 1
  end
  return runtime, contact, target, sent, addons, refresh, function()
    return refreshes
  end
end

local function inform(runtime, text, lineID)
  return Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", {
    text = text,
    playerName = "Arthas-Area52",
    guid = "Player-1",
    channel = "WOW",
    lineID = lineID,
  })
end

return function()
  assert(type(MessageReactions.VisibleReaction) == "function", "MessageReactions should expose effective visible reaction")

  local savedTimer = _G.C_Timer

  -- Successful set displays immediately but confirmed state waits for INFORM.
  do
    local timers = {}
    _G.C_Timer = {
      After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
      end,
    }
    local now = { value = 100 }
    local runtime, contact, target, sent, _, refresh, refreshCount = newRuntime(now, timers)
    assert(ReactionHandler.HandleReact(runtime, contact, target, "heart", refresh) == true, "heart send should succeed")
    assert(target.reaction == nil, "confirmed reaction must remain unchanged before inform")
    assert(target._pendingReaction and target._pendingReaction.operation == "set", "successful send should store pending set")
    assert(MessageReactions.VisibleReaction(target).key == "heart", "pending set should display heart immediately")
    assert(refreshCount() == 2, "SendHandler refresh plus pending-state refresh should happen synchronously")
    assert(#timers == 1 and timers[1].delay == 15, "pending display should schedule 15-second rollback")

    local _, meta = inform(runtime, sent[1], 1)
    assert(meta and meta.reactionChanged == true, "inform should confirm pending set")
    assert(target.reaction and target.reaction.key == "heart", "inform should commit confirmed heart")
    assert(target._pendingReaction == nil, "matching inform token should clear pending state")
  end

  -- Re-entrant INFORM during dispatch commits without installing stale pending state.
  do
    local timers = {}
    _G.C_Timer = {
      After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
      end,
    }
    local now = { value = 150 }
    local runtime, contact, target, sent, _, refresh = newRuntime(now, timers)
    local reentrantMeta
    runtime.chatApi.SendChatMessage = function(text)
      sent[#sent + 1] = text
      local _, meta = inform(runtime, text, 100)
      reentrantMeta = meta
    end
    assert(ReactionHandler.HandleReact(runtime, contact, target, "heart", refresh) == true, "re-entrant send should succeed")
    assert(reentrantMeta and reentrantMeta.reactionChanged == true, "re-entrant inform should confirm reaction during dispatch")
    assert(target.reaction and target.reaction.key == "heart", "re-entrant inform should commit confirmed heart")
    assert(target._pendingReaction == nil, "handler must not install pending state after re-entrant confirmation")
    assert(#timers == 0, "re-entrant confirmation must not schedule stale rollback timer")
  end

  -- Selecting currently visible reaction hides it immediately as pending remove.
  do
    local timers = {}
    _G.C_Timer = {
      After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
      end,
    }
    local now = { value = 200 }
    local runtime, contact, target, _, _, refresh = newRuntime(now, timers)
    target.reaction = { key = "heart", actorName = "Artio", updatedAt = 190 }
    assert(ReactionHandler.HandleReact(runtime, contact, target, "heart", refresh) == true, "remove send should succeed")
    assert(target.reaction and target.reaction.key == "heart", "confirmed heart should remain until inform")
    assert(target._pendingReaction and target._pendingReaction.operation == "remove", "same visible key should stage remove")
    assert(MessageReactions.VisibleReaction(target) == nil, "pending remove should hide badge immediately")
  end

  -- Synchronous failure leaves confirmed and visible state unchanged.
  do
    _G.C_Timer = {
      After = function()
        error("failure must not schedule timeout")
      end,
    }
    local now = { value = 300 }
    local runtime, contact, target, _, _, refresh = newRuntime(now, {})
    runtime.chatApi = {}
    target.reaction = { key = "heart", actorName = "Artio", updatedAt = 290 }
    assert(ReactionHandler.HandleReact(runtime, contact, target, "laugh", refresh) == false, "unavailable send should fail")
    assert(target._pendingReaction == nil, "failed send should not create pending state")
    assert(MessageReactions.VisibleReaction(target).key == "heart", "failed send should preserve visible confirmed heart")
  end

  -- Timeout clears only current token and reveals latest confirmed state.
  do
    local timers = {}
    _G.C_Timer = {
      After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
      end,
    }
    local now = { value = 400 }
    local runtime, contact, target, _, _, refresh, refreshCount = newRuntime(now, timers)
    target.reaction = { key = "heart", actorName = "Artio", updatedAt = 390 }
    ReactionHandler.HandleReact(runtime, contact, target, "laugh", refresh)
    local pendingToken = target._pendingReaction.token
    assert(MessageReactions.VisibleReaction(target).key == "laugh", "pending replacement should display immediately")
    local beforeTimeoutRefresh = refreshCount()
    timers[1].callback()
    assert(target._pendingReaction == nil, "timeout should clear current pending token")
    assert(MessageReactions.VisibleReaction(target).key == "heart", "timeout should roll visible state back to confirmed heart")
    assert(target.reaction.key == "heart", "timeout must not mutate confirmed state")
    assert(refreshCount() == beforeTimeoutRefresh + 1, "timeout rollback should refresh immediately")
    assert(pendingToken ~= nil, "pending token should be unique and present")
  end

  -- Rapid heart then laugh: older inform commits heart but cannot hide pending laugh.
  do
    local timers = {}
    _G.C_Timer = {
      After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
      end,
    }
    local now = { value = 500 }
    local runtime, contact, target, sent, _, refresh = newRuntime(now, timers)
    ReactionHandler.HandleReact(runtime, contact, target, "heart", refresh)
    local heartToken = target._pendingReaction.token
    ReactionHandler.HandleReact(runtime, contact, target, "laugh", refresh)
    local laughToken = target._pendingReaction.token
    assert(heartToken ~= laughToken, "rapid sends should receive unique pending tokens")
    assert(MessageReactions.VisibleReaction(target).key == "laugh", "latest pending laugh should be visible")

    inform(runtime, sent[1], 2)
    assert(target.reaction and target.reaction.key == "heart", "first inform should commit confirmed heart")
    assert(target._pendingReaction and target._pendingReaction.token == laughToken, "older inform must not clear newer pending token")
    assert(MessageReactions.VisibleReaction(target).key == "laugh", "older inform must not override visible laugh")

    inform(runtime, sent[2], 3)
    assert(target.reaction and target.reaction.key == "laugh", "second inform should commit final laugh")
    assert(target._pendingReaction == nil, "matching second inform should clear pending laugh")
    assert(MessageReactions.VisibleReaction(target).key == "laugh", "final visible state should be confirmed laugh")
  end

  _G.C_Timer = savedTimer
end
