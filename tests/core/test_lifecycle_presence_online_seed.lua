local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local OnlineNotify = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.OnlineNotify")

-- The Battle.net friend refresh that already runs records a flagged friend's
-- online state, so their next BN_FRIEND_ACCOUNT_ONLINE is a real change.
return function()
  local lines = {}
  rawset(_G, "DEFAULT_CHAT_FRAME", {
    AddMessage = function(_, text)
      lines[#lines + 1] = text
    end,
  })
  local saved = _G.C_Timer
  _G.C_Timer = nil

  local conversation = { channel = "BN", battleTag = "Friend#1", displayName = "Friend#1", notifyOnline = true }
  local Bootstrap = {
    runtime = {
      bnetApi = {},
      accountState = { settings = {} },
      store = { conversations = { ["bnet::friend"] = conversation } },
    },
  }
  local deps = {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetResolver", 1, true) then
        return {
          ScanFriendList = function()
            return {
              ["Friend#1"] = { bnetAccountID = 42, accountInfo = { battleTag = "Friend#1", isOnline = false } },
            }
          end,
        }
      end
      return require(modulePath)
    end,
  }

  Presence.handleBNetFriendEvent(Bootstrap, deps)
  assert(#lines == 0, "the refresh itself never alerts")
  OnlineNotify.handleBNetAccountEvent(Bootstrap, 42, true)
  assert(#lines == 1, "offline seen by the refresh, then online: alert")

  rawset(_G, "DEFAULT_CHAT_FRAME", nil)
  _G.C_Timer = saved
end
