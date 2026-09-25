local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local KEY = "wow::WOW::stranger"

-- Request banner buttons: Accept moves the conversation to Whispers and keeps
-- it open there; Delete removes it like the row's remove action.
return function()
  local tabCalls, selected, refreshes = {}, {}, 0
  local runtime = {
    store = Store.New({ maxMessagesPerConversation = 10 }),
    window = {
      setTabMode = function(mode)
        tabCalls[#tabCalls + 1] = mode
      end,
    },
  }
  local conversation = Store.EnsureConversation(runtime.store, KEY)
  conversation.request = true
  runtime.activeConversationKey = KEY
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    characterState = {},
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
    selectConversation = function(key)
      selected[#selected + 1] = key
    end,
  })

  -- test_accept_moves_to_whispers_and_keeps_it_open
  callbacks.onAcceptRequest({ conversationKey = KEY })
  assert(conversation.request == nil, "flag cleared")
  assert(tabCalls[1] == "whispers", "switched to Whispers")
  assert(selected[1] == KEY, "the accepted conversation stays open")

  -- test_delete_removes_the_conversation
  conversation.request = true
  callbacks.onDeleteRequest({ conversationKey = KEY })
  assert(runtime.store.conversations[KEY] == nil, "request deleted")
  assert(runtime.activeConversationKey == nil, "nothing left selected")
  assert(refreshes == 1, "window refreshed after delete")

  -- test_missing_contact_is_ignored
  callbacks.onAcceptRequest(nil)
  callbacks.onDeleteRequest(nil)
end
