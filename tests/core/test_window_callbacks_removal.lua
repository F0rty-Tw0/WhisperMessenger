local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

-- Unpinning expires against the real clock, so the fixture uses it too.
local NOW = os.time()
local SELECTED = "me::WOW::jaina"
local OTHER = "me::WOW::thrall"

-- A real runtime (the removal hook lives there) with two whisper chats and
-- one pending reaction for each.
local function build(activeKey)
  local accountState = {
    settings = {},
    conversations = {
      [SELECTED] = { conversationKey = SELECTED, channel = "WOW", messages = {}, lastActivityAt = NOW },
      [OTHER] = { conversationKey = OTHER, channel = "WOW", messages = {}, lastActivityAt = NOW },
    },
  }
  local characterState = { activeConversationKey = activeKey or SELECTED }
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, "me", {
    now = function()
      return NOW
    end,
  })
  runtime.messageReactionRuntime = {
    identityMetadata = {},
    identityMessages = {},
    operations = { sender = { { conversationKey = SELECTED }, { conversationKey = OTHER } } },
    controls = {},
  }
  local refreshes = { count = 0 }
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    accountState = accountState,
    characterState = characterState,
    refreshWindow = function()
      refreshes.count = refreshes.count + 1
    end,
  })
  return callbacks, runtime, characterState, refreshes
end

local function pendingReactionKeys(runtime)
  local keys = {}
  local queues = runtime.messageReactionRuntime and runtime.messageReactionRuntime.operations or {}
  for _, queue in pairs(queues) do
    for _, entry in ipairs(queue) do
      keys[entry.conversationKey] = true
    end
  end
  return keys
end

return function()
  -- test_removing_selected_conversation_clears_saved_selection
  do
    local callbacks, runtime, characterState, refreshes = build()

    callbacks.onRemove({ conversationKey = SELECTED })

    assert(runtime.store.conversations[SELECTED] == nil, "the chat is removed")
    assert(runtime.activeConversationKey == nil, "runtime selection is cleared")
    assert(characterState.activeConversationKey == nil, "saved selection is cleared")
    assert(refreshes.count == 1, "the window refreshes once")
  end

  -- test_removing_selected_conversation_clears_only_its_pending_reactions
  do
    local callbacks, runtime = build()

    callbacks.onRemove({ conversationKey = SELECTED })

    local pending = pendingReactionKeys(runtime)
    assert(pending[SELECTED] == nil, "the removed chat's pending reactions are dropped")
    assert(pending[OTHER] == true, "another chat's pending reactions stay")
  end

  -- test_removing_another_conversation_keeps_selection
  do
    local callbacks, runtime, characterState = build()

    callbacks.onRemove({ conversationKey = OTHER })

    assert(runtime.store.conversations[OTHER] == nil, "the chat is removed")
    assert(runtime.activeConversationKey == SELECTED and characterState.activeConversationKey == SELECTED, "selection stays")
  end

  -- test_unpinning_selected_conversation_that_then_expires_clears_selection
  do
    local callbacks, runtime, characterState = build()
    local conversation = runtime.store.conversations[SELECTED]
    conversation.pinned = true
    conversation.lastActivityAt = 1

    callbacks.onPin({ conversationKey = SELECTED })

    assert(runtime.store.conversations[SELECTED] == nil, "an old chat expires once it is unpinned")
    assert(runtime.activeConversationKey == nil, "runtime selection is cleared")
    assert(characterState.activeConversationKey == nil, "saved selection is cleared")
  end

  -- test_unpinning_selected_conversation_that_stays_keeps_selection
  do
    local callbacks, runtime, characterState = build()
    runtime.store.conversations[SELECTED].pinned = true

    callbacks.onPin({ conversationKey = SELECTED })

    assert(runtime.store.conversations[SELECTED] ~= nil, "a recent chat stays once it is unpinned")
    assert(runtime.activeConversationKey == SELECTED and characterState.activeConversationKey == SELECTED, "selection stays")
  end

  -- test_clear_all_chats_clears_selection_and_all_reaction_state
  do
    local callbacks, runtime, characterState = build()

    callbacks.onClearAllChats()

    assert(next(runtime.store.conversations) == nil, "every chat is removed")
    assert(runtime.activeConversationKey == nil, "runtime selection is cleared")
    assert(characterState.activeConversationKey == nil, "saved selection is cleared")
    assert(runtime.messageReactionRuntime == nil, "all pending reaction state is dropped")
  end

  -- test_clear_all_chats_clears_a_selection_whose_chat_is_already_gone
  -- A chat that expired while offline leaves the saved selection naming it.
  do
    local callbacks, runtime, characterState = build("me::WOW::expired")

    callbacks.onClearAllChats()

    assert(runtime.activeConversationKey == nil, "runtime selection is cleared")
    assert(characterState.activeConversationKey == nil, "saved selection is cleared")
  end

  -- test_clear_all_chats_runs_the_removal_hook_for_every_conversation
  do
    local callbacks, runtime = build()
    local forgotten = {}
    runtime.onConversationRemoved = function(key)
      forgotten[key] = true
    end
    Store.EnsureConversation(runtime.store, "channel::me::trade")

    callbacks.onClearAllChats()

    assert(forgotten[SELECTED] and forgotten[OTHER] and forgotten["channel::me::trade"], "each chat goes through the removal hook")
  end
end
