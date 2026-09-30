local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, nil, nil, {})
  ConversationPane.Refresh(pane, { conversationKey = "bnet::Arthas#1234", displayName = "Arthas#1234", channel = "BN" }, { messages = {} })

  -- test_reply_strip_hides_battletag_numbers
  ConversationPane.SetReply(pane, { wireId = "w1", direction = "in", author = "Arthas#1234", snippet = "hi" }, function() end)
  local label = FindUI.find(pane.frame, function(node)
    return node.frameType == "FontString" and type(node.text) == "string" and string.find(node.text, "Replying to", 1, true) ~= nil
  end)
  assert(label ~= nil, "reply strip label exists")
  assert(string.find(label.text, "Arthas", 1, true) and not string.find(label.text, "#1234", 1, true), "strip hides the number: " .. label.text)
end
