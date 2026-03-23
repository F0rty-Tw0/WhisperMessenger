local FakeUI = require("tests.helpers.fake_ui")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

return function()
  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  -- test_creates_label_for_incoming_message
  do
    local message = {
      direction = "in",
      kind = "user",
      text = "hello",
      sentAt = 1000,
      playerName = "Arthas",
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    assert(result ~= nil, "expected CreateSenderLabel to return a result")
    assert(result.frame ~= nil, "expected result to have a frame")
    -- Find the name FontString — it should have playerName text
    local nameFS = nil
    for _, child in ipairs(result.frame.children) do
      if child.text == "Arthas" then
        nameFS = child
      end
    end
    assert(nameFS ~= nil, "expected a FontString with playerName 'Arthas'")
  end

  -- test_creates_label_for_outgoing_message
  do
    local message = {
      direction = "out",
      kind = "user",
      text = "goodbye",
      sentAt = 2000,
      playerName = "Me",
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    assert(result ~= nil, "expected CreateSenderLabel to return a result")
    assert(result.frame ~= nil, "expected result to have a frame")
    -- Find the name FontString — it should have "You" text
    local youFS = nil
    for _, child in ipairs(result.frame.children) do
      if child.text == "You" then
        youFS = child
      end
    end
    assert(youFS ~= nil, "expected a FontString with text 'You' for outgoing message")
  end

  -- test_returns_height_18
  do
    local message = {
      direction = "in",
      kind = "user",
      text = "test",
      sentAt = 3000,
      playerName = "Bob",
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    assert(result.height == 18, "expected returned height to be 18, got " .. tostring(result.height))
  end
end
