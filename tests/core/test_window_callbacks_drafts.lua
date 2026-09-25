local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")

local KEY = "wow::WOW::jaina"

local function build()
  local runtime = { store = Store.New({ maxMessagesPerConversation = 10 }) }
  Store.EnsureConversation(runtime.store, KEY)
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    characterState = {},
    refreshWindow = function() end,
  })
  return callbacks, runtime
end

return function()
  -- test_draft_callbacks_read_and_write_the_conversation_store
  do
    local callbacks, runtime = build()
    callbacks.onDraftChanged(KEY, "see you at")
    assert(runtime.store.conversations[KEY].draft == "see you at", "draft saved on the conversation")
    assert(callbacks.getDraft(KEY) == "see you at", "draft read back")
  end

  -- test_remove_conversation_drops_its_draft
  do
    local callbacks, runtime = build()
    callbacks.onDraftChanged(KEY, "pending")
    callbacks.onRemove({ conversationKey = KEY })
    assert(runtime.store.conversations[KEY] == nil and callbacks.getDraft(KEY) == nil, "removed conversation has no draft")
  end

  -- test_clear_all_chats_drops_every_draft
  do
    local callbacks, runtime = build()
    callbacks.onDraftChanged(KEY, "pending")
    callbacks.onClearAllChats()
    assert(callbacks.getDraft(KEY) == nil and next(runtime.store.conversations) == nil, "clear all removes drafts")
  end

  -- test_clear_on_logout_drops_every_draft
  do
    local callbacks, runtime = build()
    callbacks.onDraftChanged(KEY, "pending")
    runtime.accountState = { settings = { clearOnLogout = true } }
    Presence.handlePlayerLogout({ runtime = runtime })
    assert(callbacks.getDraft(KEY) == nil, "clear on logout removes drafts")
  end
end
