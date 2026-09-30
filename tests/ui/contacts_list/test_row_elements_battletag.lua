local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local row = factory.CreateFrame("Frame", nil, parent)
  row.title = row:CreateFontString(nil, "OVERLAY")

  -- test_row_name_hides_battletag_numbers
  RowElements.updateNameLabel(row, { displayName = "Arthas#1234" }, 260)
  assert(row.title.text == "Arthas", "row shows the BattleTag without its number, got " .. tostring(row.title.text))

  -- test_row_nickname_shows_as_typed
  RowElements.updateNameLabel(row, { displayName = "Arthas#1234", nickname = "Art#1" }, 260)
  assert(row.title.text == "Art#1", "nickname is shown as-is, got " .. tostring(row.title.text))
end
