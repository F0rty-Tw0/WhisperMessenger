local ChatCover = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.ChatCover")

return function()
  -- test_no_window_is_not_covered
  assert(ChatCover.IsCovered(nil) == false, "no window: nothing covers a chat")

  -- test_window_without_the_method_is_not_covered
  assert(ChatCover.IsCovered({}) == false, "old windows count as shown")

  -- test_window_follows_its_predicate
  local shown = true
  local window = {
    isConversationPaneShown = function()
      return shown
    end,
  }
  assert(ChatCover.IsCovered(window) == false, "panes shown: not covered")
  shown = false
  assert(ChatCover.IsCovered(window) == true, "panes hidden: covered")

  -- test_uncover_selects_the_active_chat_while_the_window_is_shown
  local visible, selected = true, {}
  local runtime = { activeConversationKey = "wow::jaina" }
  local onUncovered = ChatCover.OnUncovered({
    runtime = runtime,
    isWindowVisible = function()
      return visible
    end,
    selectConversation = function(key)
      selected[#selected + 1] = key
    end,
  })
  onUncovered()
  assert(#selected == 1 and selected[1] == "wow::jaina", "active chat selected (marks it read)")

  -- test_uncover_does_nothing_for_a_hidden_window
  visible = false
  onUncovered()
  assert(#selected == 1, "hidden window: the chat is not on screen")

  -- test_uncover_does_nothing_without_an_active_chat
  visible = true
  runtime.activeConversationKey = nil
  onUncovered()
  assert(#selected == 1, "no active chat: nothing to select")
end
