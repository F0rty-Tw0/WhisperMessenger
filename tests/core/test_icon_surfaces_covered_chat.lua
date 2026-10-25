local IconSurfaces = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")

-- A visible window on the Whispers tab; `panesShown` is what the window says
-- about its chat panes (nil: the window has no such method).
local function run(panesShown)
  local previews = {}
  local window = {
    getTabMode = function()
      return "whispers"
    end,
  }
  if panesShown ~= nil then
    window.isConversationPaneShown = function()
      return panesShown
    end
  end
  local icon = {
    setUnreadCount = function() end,
    setIncomingPreview = function(sender, text)
      previews[#previews + 1] = { sender = sender, text = text }
    end,
  }
  IconSurfaces.Update({}, {
    getWindow = function()
      return window
    end,
    isWindowVisible = function()
      return true
    end,
    buildMessagePreview = function()
      return { senderName = "Jaina", messageText = "hi", classTag = "MAGE" }
    end,
    getIcon = function()
      return icon
    end,
    getMinimapIcon = function()
      return nil
    end,
    getLdbObject = function()
      return nil
    end,
  })
  return previews[#previews]
end

return function()
  -- test_preview_suppressed_while_the_chat_panes_are_shown
  assert(run(true).sender == nil, "chat on screen: no popup")

  -- test_preview_shows_while_a_panel_or_options_cover_the_chat
  local covered = run(false)
  assert(covered.sender == "Jaina" and covered.text == "hi", "covered chat: the popup is the only surface")

  -- test_window_without_the_method_counts_as_shown
  assert(run(nil).sender == nil, "old windows keep suppressing the popup")
end
