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

  -- test_delete_opens_the_next_request_in_list_order
  do
    local picked = {}
    local contacts = {
      { conversationKey = "a", channel = "WOW", isRequest = true },
      { conversationKey = "w", channel = "WOW" },
      { conversationKey = "b", channel = "WOW", isRequest = true },
      { conversationKey = "c", channel = "WOW", isRequest = true },
    }
    local requestCallbacks = WindowCallbacks.Create({
      runtime = { store = Store.New({}) },
      characterState = {},
      buildContacts = function()
        return contacts
      end,
      selectConversation = function(key)
        picked[#picked + 1] = key
      end,
    })
    requestCallbacks.onDeleteRequest({ conversationKey = "b" })
    assert(picked[1] == "c", "the request below opens, got " .. tostring(picked[1]))
    requestCallbacks.onDeleteRequest({ conversationKey = "c" })
    assert(picked[2] == "b", "the last one falls back to the request above, got " .. tostring(picked[2]))
    contacts = { { conversationKey = "a", channel = "WOW", isRequest = true } }
    requestCallbacks.onDeleteRequest({ conversationKey = "a" })
    assert(picked[3] == nil, "no requests left: nothing opens, empty page shows")
  end

  -- test_missing_contact_is_ignored
  callbacks.onAcceptRequest(nil)
  callbacks.onDeleteRequest(nil)
end
