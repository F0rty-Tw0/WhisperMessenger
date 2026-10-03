local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FilterApi = ns.BootstrapChatFilterApi or require("WhisperMessenger.Core.Bootstrap.ChatFilters.FilterApi")
local ConditionalFilters = ns.BootstrapChatFiltersConditionalFilters or require("WhisperMessenger.Core.Bootstrap.ChatFilters.ConditionalFilters")

local ChatFilters = {}

-- Hiding only some lines (ignored players, keyword rules, enabled channels)
-- needs filters that can return false. On since the in-game taint probe
-- (2026-10-03) found no reply-path taint from channel and say filters. Turning
-- it off keeps every conditional filter unregistered.
ChatFilters.SELECTIVE_HIDING = true

-- runtime: optional; without it only the whisper filters exist.
function ChatFilters.Configure(Bootstrap, accountState, runtime)
  -- Filter functions are intentionally trivial — they ALWAYS return true
  -- (suppress). We control WHEN they run via register/unregister, never
  -- via dynamic checks inside the filter body. Any addon code executing
  -- inside a ChatFrame filter taints Blizzard's secure chat context; if
  -- the filter then returns false (pass-through), the tainted execution
  -- path causes SetLastTellTarget to crash on secret string values.
  Bootstrap._whisperFilter = function()
    return true
  end

  Bootstrap._bnWhisperFilter = function()
    return true
  end

  Bootstrap._filtersRegistered = false

  -- Channel, say, yell and emote filters; never on whisper events.
  local conditional = runtime and ConditionalFilters.New(runtime) or nil

  Bootstrap.registerChatFilters = function()
    if Bootstrap._filtersRegistered or not FilterApi.IsAvailable() then
      return
    end

    FilterApi.Add("CHAT_MSG_WHISPER", Bootstrap._whisperFilter)
    FilterApi.Add("CHAT_MSG_WHISPER_INFORM", Bootstrap._whisperFilter)
    FilterApi.Add("CHAT_MSG_BN_WHISPER", Bootstrap._bnWhisperFilter)
    FilterApi.Add("CHAT_MSG_BN_WHISPER_INFORM", Bootstrap._bnWhisperFilter)
    Bootstrap._filtersRegistered = true
  end

  -- Drops every filter. Mythic+ suspend calls this without a resync, so the
  -- conditional filters go too, even when the whisper ones were never on.
  Bootstrap.unregisterChatFilters = function()
    if conditional then
      conditional.Sync(false)
    end
    if not Bootstrap._filtersRegistered then
      return
    end

    FilterApi.Remove("CHAT_MSG_WHISPER", Bootstrap._whisperFilter)
    FilterApi.Remove("CHAT_MSG_WHISPER_INFORM", Bootstrap._whisperFilter)
    FilterApi.Remove("CHAT_MSG_BN_WHISPER", Bootstrap._bnWhisperFilter)
    FilterApi.Remove("CHAT_MSG_BN_WHISPER_INFORM", Bootstrap._bnWhisperFilter)

    Bootstrap._filtersRegistered = false
  end

  Bootstrap.syncChatFilters = function()
    local allowed = not Bootstrap._inCompetitiveContent and not Bootstrap._inMythicContent and not Bootstrap._inEncounter and not _G._wmSuspended
    local shouldFilter = accountState.settings.hideFromDefaultChat == true and allowed

    if shouldFilter and not Bootstrap._filtersRegistered then
      Bootstrap.registerChatFilters()
    elseif not shouldFilter and Bootstrap._filtersRegistered then
      Bootstrap.unregisterChatFilters()
    end

    if conditional then
      conditional.Sync(allowed and ChatFilters.SELECTIVE_HIDING == true)
    end
  end
end

ns.BootstrapChatFilters = ChatFilters
return ChatFilters
