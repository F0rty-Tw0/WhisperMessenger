local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationSelector = {}

function ConversationSelector.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local characterState = options.characterState or {}
  local markConversationRead = options.markConversationRead
  local presenceCache = options.presenceCache or {}
  local requestAvailability = options.requestAvailability
  local getDiagnostics = options.getDiagnostics or function()
    return options.diagnostics or {}
  end
  local refreshWindow = options.refreshWindow or function()
    return nil
  end

  local selector = {}

  function selector.selectConversation(conversationKey)
    runtime.activeConversationKey = conversationKey
    characterState.activeConversationKey = conversationKey

    local store = runtime.store
    local conversation = conversationKey ~= nil and store.conversations[conversationKey] or nil

    if conversation ~= nil then
      markConversationRead(store, conversationKey)

      if conversation.guid then
        presenceCache.RefreshPresence(conversation.guid)
      end
      if conversation.channel == "WOW" and conversation.guid then
        requestAvailability(runtime.chatApi, conversation.guid)
      end
    end

    local diagnostics = getDiagnostics()
    if diagnostics.debugContact then
      diagnostics.debugContact(conversationKey)
    end

    return refreshWindow()
  end

  return selector
end

ns.BootstrapWindowRuntimeConversationSelector = ConversationSelector

return ConversationSelector
