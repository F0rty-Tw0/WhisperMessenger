local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsTabFilter = ns.ContactsTabFilter or require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")
local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")

local ToggleFlow = {}

-- Classified exactly like the contacts list: the conversation's snapshot
-- through ContactsTabFilter.ModeOf.
local function conversationMatchesTab(runtime, conversationKey, tabMode)
  if tabMode == nil then
    return true
  end

  local conversation = Store.Find(runtime.store, conversationKey)
  if conversation == nil then
    return true
  end

  local settings = runtime.accountState and runtime.accountState.settings
  return ContactsTabFilter.ModeOf(ConversationSnapshot.Build(conversationKey, conversation, settings)) == tabMode
end

-- toggle() returns the key of the chat it opened onto, nil when it selected
-- none (closed, compact list, or no chat on the open tab).
function ToggleFlow.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local ensureWindow = options.ensureWindow or function() end
  local isWindowVisible = options.isWindowVisible or function()
    return false
  end
  local setWindowVisible = options.setWindowVisible or function() end
  local getWindow = options.getWindow or function()
    return nil
  end
  local findLatestUnreadKey = options.findLatestUnreadKey or function(_accept)
    return nil
  end
  local selectConversation = options.selectConversation or function(_conversationKey) end
  local refreshWindow = options.refreshWindow or function() end

  local function matchesTab(conversationKey, tabMode)
    return conversationMatchesTab(runtime, conversationKey, tabMode)
  end

  -- The chat an opening toggle selects: the latest unread chat on the open
  -- tab, else the active chat when it is on that tab. Jumping to the latest
  -- unread keeps the Groups tab from losing the selection to a fresh whisper,
  -- and the Whispers tab from losing it to an unread party message.
  local function tabTargetKey()
    local window = getWindow()
    local tabMode = window and type(window.getTabMode) == "function" and window.getTabMode() or nil
    local unreadKey = findLatestUnreadKey(function(conversationKey)
      return matchesTab(conversationKey, tabMode)
    end)

    local targetKey = unreadKey or runtime.activeConversationKey
    if targetKey ~= nil and matchesTab(targetKey, tabMode) then
      return targetKey
    end

    return nil
  end

  -- The chat toggle() would open onto, without touching the window. nil when
  -- the toggle closes, or opens the compact list.
  local function openTargetKey()
    if isWindowVisible() then
      return nil
    end

    local window = getWindow()
    if window and window.isCompactLayout then
      return nil
    end

    return tabTargetKey()
  end

  local function toggle()
    ensureWindow()
    local nextVisible = not isWindowVisible()

    -- Compact layout: the button opens the list; a chat opens from a click there.
    -- A button click while a whisper preview shows never gets here: the icon
    -- click (IconToggle) opens that preview's chat first, in both layouts.
    -- Keybinds and /wm still come straight here.
    local compactWindow = getWindow()
    if nextVisible and compactWindow and compactWindow.isCompactLayout then
      selectConversation(nil)
      compactWindow.showCompactList()
      setWindowVisible(true)
      return
    end

    setWindowVisible(nextVisible)

    if nextVisible then
      local targetKey = tabTargetKey()
      if targetKey ~= nil then
        selectConversation(targetKey)
        return targetKey
      end
    end

    refreshWindow()
  end

  return {
    toggle = toggle,
    openTargetKey = openTargetKey,
    conversationMatchesTab = matchesTab,
  }
end

ns.BootstrapWindowRuntimeToggleFlow = ToggleFlow

return ToggleFlow
