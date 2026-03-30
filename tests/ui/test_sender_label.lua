local FakeUI = require("tests.helpers.fake_ui")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

local function findChildWithText(frame, text)
  for _, child in ipairs(frame.children) do
    if child.text == text then
      return child
    end
  end

  return nil
end

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

    local nameFS = findChildWithText(result.frame, "Arthas")
    assert(nameFS ~= nil, "expected a FontString with playerName 'Arthas'")
    assert(nameFS.point ~= nil, "expected incoming name label to have an anchor")
    assert(nameFS.point[1] == "LEFT", "expected incoming name anchor LEFT, got " .. tostring(nameFS.point[1]))
    assert(nameFS.point[2] == result.frame, "expected incoming name label to anchor to its frame")
    assert(
      nameFS.point[3] == "LEFT",
      "expected incoming name label relative point LEFT, got " .. tostring(nameFS.point[3])
    )
    assert(
      nameFS.point[4] == Layout.MESSAGE_EDGE_INSET,
      "expected incoming name label inset "
        .. tostring(Layout.MESSAGE_EDGE_INSET)
        .. ", got "
        .. tostring(nameFS.point[4])
    )
    assert(
      result.frame.point[1] == "TOPLEFT",
      "expected incoming label frame to anchor TOPLEFT, got " .. tostring(result.frame.point[1])
    )
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

    local youFS = findChildWithText(result.frame, "You")
    assert(youFS ~= nil, "expected a FontString with text 'You' for outgoing message")
    assert(youFS.point ~= nil, "expected outgoing name label to have an anchor")
    assert(youFS.point[1] == "RIGHT", "expected outgoing name anchor RIGHT, got " .. tostring(youFS.point[1]))
    assert(youFS.point[2] == result.frame, "expected outgoing name label to anchor to its frame")
    assert(
      youFS.point[3] == "RIGHT",
      "expected outgoing name label relative point RIGHT, got " .. tostring(youFS.point[3])
    )
    assert(
      youFS.point[4] == -Layout.MESSAGE_EDGE_INSET,
      "expected outgoing name label inset -"
        .. tostring(Layout.MESSAGE_EDGE_INSET)
        .. ", got "
        .. tostring(youFS.point[4])
    )
    assert(
      result.frame.point[1] == "TOPRIGHT",
      "expected outgoing label frame to anchor TOPRIGHT, got " .. tostring(result.frame.point[1])
    )
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
