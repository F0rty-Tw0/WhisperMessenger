local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

return function()
  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  -- test_incoming_sender_hides_battletag_numbers
  local message = { direction = "in", kind = "user", text = "hello", sentAt = 1000, playerName = "Arthas#1234" }
  local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
  assert(FindUI.text(result.frame, "Arthas") ~= nil, "sender label hides the BattleTag number")
  assert(FindUI.text(result.frame, "Arthas#1234") == nil, "full BattleTag not shown")
end
