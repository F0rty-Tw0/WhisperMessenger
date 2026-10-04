local routerCalls = 0
package.loaded["WhisperMessenger.Core.EventRouter"] = {
  HandleEvent = function()
    routerCalls = routerCalls + 1
    return nil
  end,
}
package.loaded["Core.EventRouter"] = package.loaded["WhisperMessenger.Core.EventRouter"]
package.loaded["WhisperMessenger.Core.Bootstrap.EventBridge"] = nil
package.loaded["Core.Bootstrap.EventBridge"] = nil

local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

return function()
  local gameAccountLookups = 0
  local accountLookups = 0
  local routerCallsBefore = routerCalls
  local runtime = {
    bnetApi = {
      GetGameAccountInfoByID = function()
        gameAccountLookups = gameAccountLookups + 1
        return { playerGuid = "Player-1-TEST" }
      end,
      GetAccountInfoByGUID = function()
        accountLookups = accountLookups + 1
        return { bnetAccountID = 7 }
      end,
    },
  }

  EventBridge.RouteLiveEvent(runtime, nil, "BN_CHAT_MSG_ADDON", "OTHER", "ignored", "WHISPER", 42)
  assert(gameAccountLookups == 0, "foreign BN addon prefix must not resolve game accounts")
  assert(accountLookups == 0, "foreign BN addon prefix must not resolve accounts")
  assert(routerCalls == routerCallsBefore, "foreign BN addon prefix must not reach EventRouter")

  EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_ADDON", "OTHER", "ignored", "WHISPER", "Other-Realm")
  assert(routerCalls == routerCallsBefore, "foreign addon prefix must not reach EventRouter")

  -- Wire prefixes are literals on purpose: older addon versions send exactly these.
  for _, prefix in ipairs({ "WMRX", "WMQL" }) do
    local before = routerCalls
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_ADDON", prefix, "payload", "WHISPER", "Other-Realm")
    assert(routerCalls == before + 1, prefix .. " addon message must reach EventRouter")

    before = routerCalls
    EventBridge.RouteLiveEvent(runtime, nil, "BN_CHAT_MSG_ADDON", prefix, "payload", "WHISPER", 42)
    assert(routerCalls == before + 1, prefix .. " BN addon message must reach EventRouter")
  end
end
