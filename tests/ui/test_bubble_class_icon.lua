local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  -- Bubble with classTag on message uses it for icon
  local msgWithClass = {
    direction = "in",
    kind = "user",
    text = "hello",
    classTag = "DRUID",
  }
  local bubble1 = BubbleFrame.CreateBubble(factory, parent, msgWithClass, {
    paneWidth = 400,
    showIcon = true,
  })
  assert(bubble1.icon ~= nil, "expected icon on incoming user bubble")
  assert(bubble1.icon.texturePath == Theme.ClassIcon("DRUID"), "expected class icon from message classTag")

  -- Bubble WITHOUT classTag on message but WITH fallbackClassTag in options
  local msgNoClass = {
    direction = "in",
    kind = "user",
    text = "hello from bnet",
  }
  local bubble2 = BubbleFrame.CreateBubble(factory, parent, msgNoClass, {
    paneWidth = 400,
    showIcon = true,
    fallbackClassTag = "MAGE",
  })
  assert(bubble2.icon ~= nil, "expected icon on incoming user bubble with fallback")
  assert(bubble2.icon.texturePath == Theme.ClassIcon("MAGE"), "expected class icon from fallbackClassTag, got " .. tostring(bubble2.icon.texturePath))

  -- Bubble WITHOUT classTag and WITHOUT fallback gets bnet icon
  local bubble3 = BubbleFrame.CreateBubble(factory, parent, msgNoClass, {
    paneWidth = 400,
    showIcon = true,
  })
  assert(bubble3.icon ~= nil, "expected icon on incoming user bubble without class")
  assert(bubble3.icon.texturePath == Theme.TEXTURES.bnet_icon, "expected bnet fallback icon when no classTag")
end
