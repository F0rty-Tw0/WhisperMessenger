local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")

-- The bubble of an addon-tagged whisper shows CraftScan as "Craft Alert";
-- the message keeps its text.
return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  -- test_tagged_bubble_shows_craft_alert
  local message = { text = "Found you via CraftScan", kind = "user", direction = "in", addonGreeting = "CraftScan" }
  local bubble = BubbleFrame.CreateBubble(factory, parent, message)
  local shown = bubble.frame._textFS.text
  assert(shown == "Found you via Craft Alert", "tagged bubble text: " .. tostring(shown))
  assert(message.text == "Found you via CraftScan", "the stored text stays as received")

  -- test_untagged_bubble_keeps_craftscan
  local plain = BubbleFrame.CreateBubble(factory, parent, { text = "I use CraftScan", kind = "user", direction = "in" })
  assert(plain.frame._textFS.text == "I use CraftScan", "untagged bubble text: " .. tostring(plain.frame._textFS.text))
end
