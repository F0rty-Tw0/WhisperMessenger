local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- An addon panel or the options pane hides the chat panes while the window
-- stays shown: the selected chat is then not on screen, so a whisper to it
-- is not read, shows its preview and unread number, and sends no receipt.
local ChatCover = {}

--- True when the window reports its chat panes hidden. A window without the
-- method (or no window) counts as shown.
function ChatCover.IsCovered(window)
  return window ~= nil and type(window.isConversationPaneShown) == "function" and window.isConversationPaneShown() == false
end

--- Window callback for "the chat panes came back on screen": selecting the
-- active chat marks it read, refreshes every surface and syncs receipts. A
-- hidden window ignores it (closing the window closes the panel first).
function ChatCover.OnUncovered(options)
  local runtime = options.runtime
  local isWindowVisible = options.isWindowVisible
  local selectConversation = options.selectConversation

  return function()
    local conversationKey = runtime.activeConversationKey
    if conversationKey == nil or not isWindowVisible() then
      return
    end
    selectConversation(conversationKey)
  end
end

ns.BootstrapWindowCoordinatorChatCover = ChatCover
return ChatCover
