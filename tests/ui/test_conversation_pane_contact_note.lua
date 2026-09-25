local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

-- The note line is wired through the full conversation pane, and refits
-- when the pane is resized.
return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, nil, nil)
  local contact = { conversationKey = "wow::arthas", channel = "WOW", displayName = "Arthas", note = "Raid leader" }

  -- test_pane_shows_the_contact_note
  ConversationPane.Refresh(pane, contact, { messages = {} })
  assert(pane.headerNote ~= nil and pane.headerNote:IsShown(), "note visible in the pane header")
  local noteText = tostring(pane.headerNote.text)
  assert(string.find(noteText, "Raid leader|r", 1, true), "note text, got " .. noteText)

  -- test_resize_refits_the_note_width
  ConversationPane.Relayout(pane, 800, 420)
  assert(pane.headerNote.width == 320, "wide pane: note capped at 40% of the new width, got " .. tostring(pane.headerNote.width))
end
