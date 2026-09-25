local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local Identity = require("WhisperMessenger.Model.Identity")

-- A Battle.net chat first keyed by the session account ID moves to its
-- stable BattleTag key once the friend list is readable. Session state keyed
-- by conversation (online watch, "New messages" divider) moves with it.
return function()
  local saved = _G.C_Timer
  _G.C_Timer = nil

  local oldKey = "bnet::BN::42"
  local newKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(42, { battleTag = "Friend#1" }).contactKey)
  assert(newKey ~= oldKey, "fixture: the key changes")
  local divided = { kind = "user", direction = "in", text = "hi" }
  local Bootstrap = {
    runtime = {
      bnetApi = {},
      accountState = { settings = {} },
      store = { conversations = { [oldKey] = { channel = "BN", bnetAccountID = 42, displayName = "42", messages = { divided } } } },
      onlineWatch = { [oldKey] = false },
      unreadDivider = { conversationKey = oldKey, message = divided },
    },
  }
  local deps = {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetResolver", 1, true) then
        return {
          ScanFriendList = function()
            return { ["Friend#1"] = { bnetAccountID = 42, accountInfo = { battleTag = "Friend#1" } } }
          end,
        }
      end
      return require(modulePath)
    end,
  }

  Presence.handleBNetFriendEvent(Bootstrap, deps)

  local runtime = Bootstrap.runtime
  assert(runtime.store.conversations[newKey] ~= nil, "fixture: conversation rekeyed")
  -- test_online_watch_follows_the_rekey
  assert(runtime.onlineWatch[newKey] == false and runtime.onlineWatch[oldKey] == nil, "online watch moved to the new key")
  -- test_unread_divider_follows_the_rekey
  assert(runtime.unreadDivider.conversationKey == newKey, "divider moved to the new key")

  _G.C_Timer = saved
end
