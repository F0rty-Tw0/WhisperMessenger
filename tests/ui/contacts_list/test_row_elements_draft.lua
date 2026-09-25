local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")
local UIHelpers = require("WhisperMessenger.UI.Helpers")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local KEY = "me::WOW::alice"

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local row = factory.CreateFrame("Frame", nil, parent)
  row.classIconFrame = factory.CreateFrame("Frame", nil, row)

  -- test_snapshot_carries_the_conversation_draft
  local item = ConversationSnapshot.Build(KEY, { displayName = "Alice", lastPreview = "hello", draft = "see you" })
  assert(item.draft == "see you", "contact item should carry the draft")

  local marker = UIHelpers.colorEscape(Theme.COLORS.danger_text) .. "Draft:|r"

  -- test_preview_shows_colored_draft_marker_instead_of_last_message
  RowElements.createPreview(row, item, 260)
  RowElements.updatePreview(row, item, 260, false, nil)
  assert(row.preview.text == marker .. " see you", "draft replaces the preview, got " .. tostring(row.preview.text))

  -- test_hidden_previews_show_only_the_draft_marker
  RowElements.updatePreview(row, item, 260, true, nil)
  assert(
    row.preview.text == UIHelpers.colorEscape(Theme.COLORS.danger_text) .. "Draft|r",
    "only 'Draft' when previews are hidden, got " .. tostring(row.preview.text)
  )

  -- test_selected_conversation_shows_its_normal_preview
  RowElements.updatePreview(row, item, 260, false, KEY)
  assert(row.preview.text == "hello", "the open conversation's own row keeps its last message, got " .. tostring(row.preview.text))

  -- test_typing_indicator_wins_over_draft
  item.isTyping = true
  RowElements.updatePreview(row, item, 260, false, nil)
  assert(string.find(row.preview.text, "typing", 1, true) == 1, "typing indicator takes the slot")
  item.isTyping = false

  -- test_no_draft_keeps_last_message
  item.draft = nil
  RowElements.updatePreview(row, item, 260, false, nil)
  assert(row.preview.text == "hello", "no draft -> last message")
end
