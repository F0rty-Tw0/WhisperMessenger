local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")

local ToggleFlow = {}

local function conversationMatchesTab(runtime, badgeFilter, conversationKey, tabMode)
  if tabMode == nil then
    return true
  end

  local conversation = runtime.store and runtime.store.conversations and runtime.store.conversations[conversationKey] or nil
  if conversation == nil then
    return true
  end

  local isGroup = badgeFilter.IsGroupChannel(conversation.channel)
  if tabMode == "groups" then
    return isGroup
  end

  return not isGroup
end

function ToggleFlow.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local badgeFilter = options.badgeFilter or BadgeFilter
  local ensureWindow = options.ensureWindow or function() end
  local isWindowVisible = options.isWindowVisible or function()
    return false
  end
  local setWindowVisible = options.setWindowVisible or function() end
  local getWindow = options.getWindow or function()
    return nil
  end
  local findLatestUnreadKey = options.findLatestUnreadKey or function()
    return nil
  end
  local selectConversation = options.selectConversation or function() end
  local refreshWindow = options.refreshWindow or function() end

  local function matchesTab(conversationKey, tabMode)
    return conversationMatchesTab(runtime, badgeFilter, conversationKey, tabMode)
  end

  local function toggle()
    ensureWindow()
    local nextVisible = not isWindowVisible()
    setWindowVisible(nextVisible)

    if nextVisible then
      local window = getWindow()
      local tabMode = window and type(window.getTabMode) == "function" and window.getTabMode() or nil
      local unreadKey = findLatestUnreadKey()
      -- Gate the "jump to unread" shortcut by the current tab: on the Groups
      -- tab we don't want a freshly-received whisper to steal the selection,
      -- and on the Whispers tab an unread party message shouldn't.
      if unreadKey and not matchesTab(unreadKey, tabMode) then
        unreadKey = nil
      end

      local targetKey = unreadKey or runtime.activeConversationKey
      if targetKey ~= nil and matchesTab(targetKey, tabMode) then
        selectConversation(targetKey)
        return
      end
    end

    refreshWindow()
  end

  return {
    toggle = toggle,
    conversationMatchesTab = matchesTab,
  }
end

ns.BootstrapWindowRuntimeToggleFlow = ToggleFlow

return ToggleFlow
