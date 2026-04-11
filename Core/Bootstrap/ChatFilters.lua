local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatFilters = {}

function ChatFilters.Configure(Bootstrap, accountState)
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

  Bootstrap.registerChatFilters = function()
    if Bootstrap._filtersRegistered or type(_G.ChatFrame_AddMessageEventFilter) ~= "function" then
      return
    end

    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", Bootstrap._whisperFilter)
    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", Bootstrap._whisperFilter)
    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", Bootstrap._bnWhisperFilter)
    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", Bootstrap._bnWhisperFilter)
    Bootstrap._filtersRegistered = true
  end

  Bootstrap.unregisterChatFilters = function()
    if not Bootstrap._filtersRegistered then
      return
    end

    if type(_G.ChatFrame_RemoveMessageEventFilter) == "function" then
      _G.ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", Bootstrap._whisperFilter)
      _G.ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", Bootstrap._whisperFilter)
      _G.ChatFrame_RemoveMessageEventFilter("CHAT_MSG_BN_WHISPER", Bootstrap._bnWhisperFilter)
      _G.ChatFrame_RemoveMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", Bootstrap._bnWhisperFilter)
    end

    Bootstrap._filtersRegistered = false
  end

  Bootstrap.syncChatFilters = function()
    local shouldFilter = accountState.settings.hideFromDefaultChat == true
      and not Bootstrap._inCompetitiveContent
      and not Bootstrap._inMythicContent
      and not Bootstrap._inEncounter
      and not _G._wmSuspended

    if shouldFilter and not Bootstrap._filtersRegistered then
      Bootstrap.registerChatFilters()
    elseif not shouldFilter and Bootstrap._filtersRegistered then
      Bootstrap.unregisterChatFilters()
    end
  end
end

ns.BootstrapChatFilters = ChatFilters
return ChatFilters
