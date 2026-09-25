local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local OnlineWatch = require("WhisperMessenger.Model.OnlineWatch")

local KEY = "wow::WOW::jaina"

return function()
  local refreshes = 0
  local runtime = { store = Store.New({ maxMessagesPerConversation = 10 }) }
  Store.EnsureConversation(runtime.store, KEY)
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    characterState = {},
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  })

  -- test_update_prefs_saves_on_the_conversation_and_refreshes
  callbacks.onUpdatePrefs({ conversationKey = KEY }, { muted = true })
  assert(runtime.store.conversations[KEY].muted == true, "mute saved")
  assert(refreshes == 1, "window refreshed so rows, header and badges update")

  callbacks.onUpdatePrefs({ conversationKey = KEY }, { nickname = " Jai " })
  assert(runtime.store.conversations[KEY].nickname == "Jai", "nickname saved trimmed")

  -- test_update_prefs_without_item_is_ignored
  callbacks.onUpdatePrefs(nil, { muted = true })
  assert(refreshes == 2, "nothing to update, no refresh")

  -- test_notify_online_on_records_current_state
  -- Turning it on records the friend's current state right away, so the very
  -- next login is noticed even without a friend-list update in between.
  do
    local watchRuntime = {
      store = { conversations = { k = { channel = "WOW", displayName = "Jaina-Realm" } } },
      friendListApi = {
        GetFriendInfo = function()
          return { connected = false }
        end,
      },
    }
    local watchCallbacks = WindowCallbacks.Create({ runtime = watchRuntime, characterState = {} })
    watchCallbacks.onUpdatePrefs({ conversationKey = "k" }, { notifyOnline = true })
    assert(OnlineWatch.Observe(watchRuntime, "k", true) == true, "offline recorded at toggle time, so coming online alerts")
  end
end
