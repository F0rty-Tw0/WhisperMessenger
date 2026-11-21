local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

-- Stored incoming character lines drop a classTag that matches the chat's
-- class, so their bubble icon comes from the open contact's class.
return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, nil, nil)

  -- test_incoming_line_without_class_tag_uses_contact_class_icon
  local contact = { conversationKey = "wow::uther", displayName = "Uther", channel = "WOW", classTag = "PALADIN" }
  local line = { direction = "in", kind = "user", text = "hi", sentAt = 10, playerName = "Uther" }
  ConversationPane.Refresh(pane, contact, { messages = { line } })

  local paladinIcon = Theme.ClassIcon("PALADIN")
  -- The header shows the contact's class icon too: search the transcript only.
  local icon = FindUI.find(pane.transcript.scrollFrame, function(node)
    return node.texturePath == paladinIcon
  end)
  assert(icon ~= nil, "incoming line without classTag should show the PALADIN class icon")
end
