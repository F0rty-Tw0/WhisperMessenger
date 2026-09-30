local FakeUI = require("tests.helpers.fake_ui")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_header_name_hides_battletag_numbers
  local header = HeaderView.Create(factory, pane, { displayName = "Arthas#1234", channel = "BN" })
  assert(header.headerName.text == "Arthas", "header shows the BattleTag without its number, got " .. tostring(header.headerName.text))
end
