local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AutoOpenHooks = {}

function AutoOpenHooks.Create(deps)
  local hooks = {}
  local log = deps.trace

  local function shouldAutoOpen()
    local settings = deps.getSettings()
    if not settings or settings.autoOpenWindow ~= true then
      if log then
        log("AutoOpen: shouldAutoOpen=false (setting off)")
      end
      return false
    end
    if deps.isInCombat() then
      if log then
        log("AutoOpen: shouldAutoOpen=false (in combat)")
      end
      return false
    end
    return true
  end

  local function openAndSelect(conversationKey, forceFocus)
    deps.ensureWindow()
    deps.setWindowVisible(true)
    deps.selectConversation(conversationKey)
    if forceFocus then
      deps.focusComposer()
    end
  end

  function hooks.onIncomingWhisper(conversationKey)
    if not conversationKey then
      return
    end
    -- When the window is already open and the user is viewing a conversation,
    -- don't steal focus by switching to the new whisper's conversation.
    local isVisible = deps.isWindowVisible and deps.isWindowVisible()
    local activeKey = deps.getActiveConversationKey and deps.getActiveConversationKey()
    if isVisible and activeKey then
      return
    end
    openAndSelect(conversationKey, false)
  end

  function hooks.onReplyTell()
    if not shouldAutoOpen() then
      return false
    end
    -- Use the last incoming whisper key tracked by runtime
    local conversationKey = deps.getLastReplyKey and deps.getLastReplyKey()
    if log then
      log("AutoOpen: onReplyTell key=" .. tostring(conversationKey))
    end
    if not conversationKey then
      return false
    end
    openAndSelect(conversationKey, true)
    return true
  end

  function hooks.onSendTell(playerName)
    if not shouldAutoOpen() then
      return false
    end
    if not playerName then
      return false
    end
    local conversationKey = deps.findConversationKeyByName(playerName)
    if not conversationKey and deps.buildConversationKeyFromName then
      conversationKey = deps.buildConversationKeyFromName(playerName)
    end
    if log then
      log("AutoOpen: onSendTell name=" .. tostring(playerName) .. " key=" .. tostring(conversationKey))
    end
    if not conversationKey then
      return false
    end
    -- Ensure a conversation exists so the contact list shows the target
    if deps.ensureConversation then
      deps.ensureConversation(conversationKey, playerName)
    end
    openAndSelect(conversationKey, true)
    return true
  end

  function hooks.onOutgoingWhisper(conversationKey)
    if not conversationKey then
      return false
    end
    openAndSelect(conversationKey, true)
    return true
  end

  return hooks
end

ns.BootstrapAutoOpenHooks = AutoOpenHooks
return AutoOpenHooks
