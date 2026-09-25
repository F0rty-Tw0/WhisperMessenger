local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

local function findDivider(content)
  for _, frame in ipairs(content._activeFrames or {}) do
    if frame._labelFS and frame._labelFS:GetText() == "New messages" then
      return frame
    end
  end
  return nil
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, nil, nil)

  local messages = {
    { kind = "user", direction = "in", text = "read", sentAt = 1, playerName = "Guildie" },
    { kind = "user", direction = "in", text = "unread", sentAt = 2, playerName = "Guildie" },
  }
  local conversation = { messages = messages }

  -- test_group_conversation_shows_divider_from_selected_contact
  local contact = { conversationKey = "guild::Stormwind", channel = "GUILD", displayName = "Guild", unreadDividerMessage = messages[2] }
  ConversationPane.Refresh(pane, contact, conversation)
  assert(findDivider(pane.transcript.content) ~= nil, "divider shown before the first unread message")

  -- test_divider_hidden_when_selection_has_none
  local cleared = { conversationKey = "guild::Stormwind", channel = "GUILD", displayName = "Guild" }
  ConversationPane.Refresh(pane, cleared, conversation)
  assert(findDivider(pane.transcript.content) == nil, "no divider without one on the selection")
end
