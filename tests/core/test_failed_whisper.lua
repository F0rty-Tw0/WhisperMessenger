local Router = require("WhisperMessenger.Core.EventRouter")
local Store = require("WhisperMessenger.Model.ConversationStore")
local Constants = require("WhisperMessenger.Core.Constants")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local LivePayload = require("WhisperMessenger.Core.Bootstrap.EventBridge.LivePayload")

-- A whisper is marked failed only on positive evidence: the game's
-- "No player named '%s' is currently playing." line for a target we have
-- a pending (not yet echoed) send to. A timeout alone never marks anything,
-- and a send past its 15s echo window is stale: never marked failed.

local TEMPLATE = "No player named '%s' is currently playing."

-- clock: optional { value = seconds }, for moving time forward.
local function newState(clock)
  clock = clock or { value = 100 }
  return {
    localProfileId = "me",
    pendingOutgoing = {},
    now = function()
      return clock.value
    end,
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10, messageMaxAge = 86400, conversationMaxAge = 86400 }),
  }
end

local function recordSend(state, text)
  return Router.RecordPendingSend(state, {
    channel = "WOW",
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    guid = "Player-1",
  }, text, { replyTo = { wireId = "w1" } })
end

-- How many live payloads a system line built: 0 means it was skipped early.
local function countPayloadBuilds(state, text)
  local savedBuild = LivePayload.Build
  local built = 0
  rawset(LivePayload, "Build", function(...)
    built = built + 1
    return savedBuild(...)
  end)
  EventBridge.RouteLiveEvent(state, function() end, "CHAT_MSG_SYSTEM", text)
  rawset(LivePayload, "Build", savedBuild)
  return built
end

return function()
  rawset(_G, "ERR_CHAT_PLAYER_NOT_FOUND_S", TEMPLATE)

  -- test_system_event_is_registered
  do
    local registered = false
    for _, name in ipairs(Constants.LIVE_EVENT_NAMES) do
      registered = registered or name == "CHAT_MSG_SYSTEM"
    end
    assert(registered, "CHAT_MSG_SYSTEM must be a live event")
  end

  -- test_player_not_found_marks_the_pending_send_failed
  do
    local state = newState()
    local key = recordSend(state, "hello")
    local conversation = Router.HandleEvent(state, "CHAT_MSG_SYSTEM", { text = string.format(TEMPLATE, "Thrall-Nagrand") })
    assert(conversation ~= nil and conversation.conversationKey == key, "returns the conversation to refresh")
    local message = state.store.conversations[key].messages[1]
    assert(message.delivery == "failed" and message.text == "hello", "stored as failed")
    assert(message.direction == "out" and message.sentAt == 100, "at the time it was sent")
    assert(message.replyTo and message.replyTo.wireId == "w1", "reply kept for retry context")
    assert(state.pendingOutgoing[key] == nil, "pending consumed")
  end

  -- test_other_system_lines_change_nothing
  do
    local state = newState()
    local key = recordSend(state, "hello")
    assert(Router.HandleEvent(state, "CHAT_MSG_SYSTEM", { text = "Thrall-Nagrand has come online." }) == nil, "unrelated line")
    assert(Router.HandleEvent(state, "CHAT_MSG_SYSTEM", { text = string.format(TEMPLATE, "Jaina") }) == nil, "other target")
    assert(state.store.conversations[key] == nil, "nothing stored")
    assert(#state.pendingOutgoing[key] == 1, "pending kept")
  end

  -- test_secret_system_text_is_skipped
  do
    local state = newState()
    local key = recordSend(state, "hello")
    local saved = Router._isSecretString
    Router._isSecretString = function(value)
      return value ~= nil
    end
    assert(Router.HandleEvent(state, "CHAT_MSG_SYSTEM", { text = string.format(TEMPLATE, "Thrall-Nagrand") }) == nil, "secret text skipped")
    Router._isSecretString = saved
    assert(#state.pendingOutgoing[key] == 1, "pending kept")
  end

  -- test_reaction_fallback_is_never_marked_failed
  do
    local state = newState()
    local key = Router.RecordPendingSend(state, { channel = "WOW", target = "Thrall-Nagrand", displayName = "Thrall-Nagrand" }, "reacted", {
      reactionControl = { operation = {} },
    })
    assert(Router.HandleEvent(state, "CHAT_MSG_SYSTEM", { text = string.format(TEMPLATE, "Thrall-Nagrand") }) == nil, "reaction ignored")
    assert(#state.pendingOutgoing[key] == 1, "reaction pending kept")
  end

  -- test_bridge_routes_the_failure_and_skips_idle_system_lines
  do
    local state = newState()
    local refreshed = {}
    local key = recordSend(state, "hello")
    EventBridge.RouteLiveEvent(state, function(k)
      refreshed[#refreshed + 1] = k
    end, "CHAT_MSG_SYSTEM", string.format(TEMPLATE, "Thrall-Nagrand"))
    assert(refreshed[1] == key, "window refreshed for the failed conversation")

    assert(countPayloadBuilds(state, "You are now AFK.") == 0, "no pending sends: system lines cost nothing")
  end

  -- test_stale_pending_send_is_never_marked_failed
  do
    local clock = { value = 100 }
    local state = newState(clock)
    local key = recordSend(state, "hello")
    clock.value = 130
    assert(Router.HandleEvent(state, "CHAT_MSG_SYSTEM", { text = string.format(TEMPLATE, "Thrall-Nagrand") }) == nil, "stale send ignored")
    assert(state.store.conversations[key] == nil, "no Not sent message for a stale send")
  end

  -- test_stale_pending_send_does_not_keep_the_gate_open
  do
    local clock = { value = 100 }
    local state = newState(clock)
    recordSend(state, "hello")
    clock.value = 130
    assert(countPayloadBuilds(state, "You are now AFK.") == 0, "only stale sends pending: system lines cost nothing")
    assert(next(state.pendingOutgoing) == nil, "stale entries pruned")
  end

  -- test_failed_whisper_to_roster_member_fills_class
  do
    local state = newState()
    state.clubApi = {
      GetSubscribedClubs = function()
        return { { clubId = 7 } }
      end,
      GetClubMembers = function()
        return { 1 }
      end,
      GetMemberInfo = function()
        return { name = "Paokremounia", guid = "Player-9" }
      end,
    }
    state.playerInfoByGUID = function(guid)
      assert(guid == "Player-9", "class looked up by the roster guid")
      return "Hunter", "HUNTER", "Orc", "Orc"
    end
    local key = Router.RecordPendingSend(state, { channel = "WOW", target = "Paokremounia", displayName = "Paokremounia" }, "hey")
    Router.HandleEvent(state, "CHAT_MSG_SYSTEM", { text = string.format(TEMPLATE, "Paokremounia") })
    local conversation = state.store.conversations[key]
    assert(conversation.guid == "Player-9", "guid from roster, got " .. tostring(conversation.guid))
    assert(conversation.classTag == "HUNTER" and conversation.raceName == "Orc", "class and race stored")
  end

  -- test_missing_template_is_skipped
  do
    rawset(_G, "ERR_CHAT_PLAYER_NOT_FOUND_S", nil)
    local state = newState()
    recordSend(state, "hello")
    assert(Router.HandleEvent(state, "CHAT_MSG_SYSTEM", { text = string.format(TEMPLATE, "Thrall-Nagrand") }) == nil, "no template: no guess")
  end
end
