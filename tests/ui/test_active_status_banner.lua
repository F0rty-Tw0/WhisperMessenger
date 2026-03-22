local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)

  local conversation = {
    messages = {
      { id = "1", kind = "user", direction = "in", text = "hi", sentAt = 1, playerName = "Arthas" },
    },
    activeStatus = nil,
  }

  local pane = ConversationPane.Create(factory, parent, {
    displayName = "Arthas",
  }, conversation)

  -- activeStatusBanner should exist on the view
  assert(pane.activeStatusBanner ~= nil, "expected activeStatusBanner to exist")

  -- Initially hidden when no activeStatus
  ConversationPane.RefreshActiveStatus(pane, nil)
  assert(pane.activeStatusBanner.shown == false, "expected banner hidden when no activeStatus")

  -- Show banner when activeStatus is set
  ConversationPane.RefreshActiveStatus(pane, { text = "Away from keyboard", eventName = "CHAT_MSG_AFK" })
  assert(pane.activeStatusBanner.shown == true, "expected banner visible for AFK")
  assert(pane.activeStatusBanner.text == "Away from keyboard", "expected banner text to match")

  -- DND status
  ConversationPane.RefreshActiveStatus(pane, { text = "Do not disturb", eventName = "CHAT_MSG_DND" })
  assert(pane.activeStatusBanner.shown == true, "expected banner visible for DND")
  assert(pane.activeStatusBanner.text == "Do not disturb")

  -- Clear again
  ConversationPane.RefreshActiveStatus(pane, nil)
  assert(pane.activeStatusBanner.shown == false, "expected banner hidden after clear")
  assert(pane.activeStatusBanner.text == "", "expected banner text cleared")
end
