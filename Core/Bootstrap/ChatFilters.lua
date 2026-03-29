local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatFilters = {}

function ChatFilters.Configure(Bootstrap, accountState)
  Bootstrap._whisperFilter = function()
    if accountState.settings.hideFromDefaultChat ~= true then
      return false
    end
    return true
  end

  Bootstrap._bnWhisperFilter = function()
    if accountState.settings.hideFromDefaultChat ~= true then
      return false
    end
    return true
  end

  Bootstrap._filtersRegistered = false

  Bootstrap.registerChatFilters = function()
    if Bootstrap._filtersRegistered or type(_G.ChatFrame_AddMessageEventFilter) ~= "function" then
      return
    end

    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", Bootstrap._whisperFilter)
    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", Bootstrap._bnWhisperFilter)
    Bootstrap._filtersRegistered = true
  end

  Bootstrap.unregisterChatFilters = function()
    if not Bootstrap._filtersRegistered then
      return
    end

    if type(_G.ChatFrame_RemoveMessageEventFilter) == "function" then
      _G.ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", Bootstrap._whisperFilter)
      _G.ChatFrame_RemoveMessageEventFilter("CHAT_MSG_BN_WHISPER", Bootstrap._bnWhisperFilter)
    end

    Bootstrap._filtersRegistered = false
  end
end

ns.BootstrapChatFilters = ChatFilters
return ChatFilters
