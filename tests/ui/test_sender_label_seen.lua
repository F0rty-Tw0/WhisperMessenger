local FakeUI = require("tests.helpers.fake_ui")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")

local function findChildWithText(frame, text)
  for _, child in ipairs(frame.children or {}) do
    if child.text == text then
      return child
    end
  end
  return nil
end

local function countVisibleSeen(contentFrame)
  local count = 0
  for _, child in ipairs(contentFrame.children or {}) do
    local seen = findChildWithText(child, "Seen")
    if seen and seen.shown ~= false and child.shown ~= false then
      count = count + 1
    end
  end
  return count
end

local function outgoing(text, sentAt, wireId, seenAt)
  return {
    direction = "out",
    kind = "user",
    text = text,
    sentAt = sentAt,
    wireId = wireId,
    seenAt = seenAt,
    senderName = "Me",
    playerName = "Arthas",
  }
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_outgoing_label_shows_seen_when_requested
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)
    local message = outgoing("hi", 1000, "w0", 1010)
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0, { showSeen = true })
    local seen = findChildWithText(result.frame, "Seen")
    assert(seen ~= nil, "expected a Seen label")
    assert(seen.shown ~= false, "Seen label visible")

    local plain = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    assert(findChildWithText(plain.frame, "Seen") == nil, "no Seen label without the option")
  end

  -- test_layout_marks_only_the_last_fully_seen_group
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)
    local messages = {
      outgoing("a", 0, "w1", 5),
      { direction = "in", kind = "user", text = "b", sentAt = 10, playerName = "Arthas" },
      outgoing("c", 20, "w2", 25),
      outgoing("d", 30, "w3", nil),
    }
    Layout.LayoutMessages(factory, contentFrame, messages, 400, {})
    assert(countVisibleSeen(contentFrame) == 0, "group with an unseen tail shows no Seen")

    messages[4].seenAt = 35
    Layout.LayoutMessages(factory, contentFrame, messages, 400, {})
    assert(countVisibleSeen(contentFrame) == 1, "exactly one Seen once the newest group is fully seen")

    table.insert(messages, outgoing("e", 500, "w4", nil))
    Layout.LayoutMessages(factory, contentFrame, messages, 400, {})
    assert(countVisibleSeen(contentFrame) == 1, "Seen stays on the last seen group while a newer group waits")
  end
end
