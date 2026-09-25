local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")

local ConversationSelector = {}

-- The oldest of the last `unreadCount` incoming user messages; when fewer are
-- stored, the oldest stored one. nil when there is none.
local function firstUnreadMessage(conversation)
  local remaining = conversation.unreadCount or 0
  if remaining <= 0 or type(conversation.messages) ~= "table" then
    return nil
  end
  local found
  for index = #conversation.messages, 1, -1 do
    local message = conversation.messages[index]
    if message.kind == "user" and message.direction == "in" then
      found = message
      remaining = remaining - 1
      if remaining == 0 then
        break
      end
    end
  end
  return found
end

-- "New messages" divider (session only, never saved): set when a conversation
-- opens with unread messages, kept while it stays selected, dropped when
-- another conversation opens.
local function updateUnreadDivider(runtime, conversationKey, conversation)
  local message = conversation and firstUnreadMessage(conversation) or nil
  if message ~= nil then
    runtime.unreadDivider = { conversationKey = conversationKey, message = message }
  elseif runtime.unreadDivider and runtime.unreadDivider.conversationKey ~= conversationKey then
    runtime.unreadDivider = nil
  end
end

-- Callers that open a whisper force the Whispers tab first; a message
-- request lives in the Requests tab, so switch there instead. Runs before
-- the selection is stored: the tab swap restores that tab's own selection.
local function showRequestsTab(runtime, conversation)
  local window = runtime.window
  if window == nil or type(window.getTabMode) ~= "function" or type(window.setTabMode) ~= "function" then
    return
  end
  local settings = runtime.accountState and runtime.accountState.settings
  if window.getTabMode() ~= "requests" and MessageRequests.IsRequest(conversation, settings) then
    window.setTabMode("requests")
  end
end

function ConversationSelector.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local characterState = options.characterState or {}
  local markConversationRead = options.markConversationRead
  local presenceCache = options.presenceCache or {}
  local requestAvailability = options.requestAvailability
  local refreshWindow = options.refreshWindow or function()
    return nil
  end

  local selector = {}

  function selector.selectConversation(conversationKey)
    local store = runtime.store
    local conversation = conversationKey ~= nil and store.conversations[conversationKey] or nil
    showRequestsTab(runtime, conversation)

    runtime.activeConversationKey = conversationKey
    characterState.activeConversationKey = conversationKey
    updateUnreadDivider(runtime, conversationKey, conversation)

    if conversation ~= nil then
      markConversationRead(store, conversationKey)

      if conversation.guid then
        presenceCache.RefreshPresence(conversation.guid)
      end
      if conversation.channel == "WOW" and conversation.guid then
        requestAvailability(runtime.chatApi, conversation.guid)
      end
    end

    return refreshWindow()
  end

  return selector
end

ns.BootstrapWindowRuntimeConversationSelector = ConversationSelector

return ConversationSelector
