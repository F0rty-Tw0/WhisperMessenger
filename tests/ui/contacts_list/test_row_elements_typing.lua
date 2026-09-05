local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  -- test_preview_shows_typing_instead_of_last_message
  local row = factory.CreateFrame("Frame", nil, parent)
  row.classIconFrame = factory.CreateFrame("Frame", nil, row)
  local item = { displayName = "Alice", lastPreview = "hello", isTyping = true }
  RowElements.createPreview(row, item, 260)
  assert(string.find(row.preview.text, "typing", 1, true) == 1, "typing preview, got " .. tostring(row.preview.text))
  local online = Theme.COLORS.online
  assert(row.preview.textColor[1] == online[1] and row.preview.textColor[2] == online[2], "typing preview uses online color")

  -- test_preview_returns_to_last_message_when_typing_stops
  item.isTyping = false
  RowElements.updatePreview(row, item, 260, false)
  assert(row.preview.text == "hello", "preview restored, got " .. tostring(row.preview.text))
  local secondary = Theme.COLORS.text_secondary
  assert(row.preview.textColor[1] == secondary[1] and row.preview.textColor[2] == secondary[2], "preview color restored")

  -- test_hidden_preview_still_shows_typing
  item.isTyping = true
  RowElements.updatePreview(row, item, 260, true)
  assert(string.find(row.preview.text, "typing", 1, true) == 1, "typing visible even when previews are hidden")
end
