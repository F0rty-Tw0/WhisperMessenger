local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

return function()
  local refreshes = 0
  local runtime = { store = Store.New({ maxMessagesPerConversation = 10 }) }
  Store.EnsureConversation(runtime.store, "wow::WOW::jaina").unreadCount = 3
  Store.EnsureConversation(runtime.store, "channel::GUILD").unreadCount = 5
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    characterState = {},
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  })

  -- test_mark_all_read_clears_every_conversation_and_refreshes
  callbacks.onMarkAllRead()
  assert(runtime.store.conversations["wow::WOW::jaina"].unreadCount == 0, "whisper read")
  assert(runtime.store.conversations["channel::GUILD"].unreadCount == 0, "group read")
  assert(refreshes == 1, "window refreshed so rows and badges update")
end
