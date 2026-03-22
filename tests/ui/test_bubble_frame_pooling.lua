local FakeUI = require("tests.helpers.fake_ui")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")

return function()
  local createCount = 0
  local baseFactory = FakeUI.NewFactory()
  local factory = {
    CreateFrame = function(frameType, name, parent, template)
      createCount = createCount + 1
      return baseFactory.CreateFrame(frameType, name, parent, template)
    end,
  }

  local contentFrame = baseFactory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  local messages3 = {
    {
      direction = "in",
      kind = "user",
      text = "hello",
      sentAt = 1000,
      playerName = "Arthas",
    },
    {
      direction = "in",
      kind = "user",
      text = "how are you",
      sentAt = 1001,
      playerName = "Arthas",
    },
    {
      direction = "out",
      kind = "user",
      text = "good thanks",
      sentAt = 1002,
      playerName = "Me",
    },
  }

  -- TEST 1: Second render reuses frames (zero new CreateFrame calls)
  createCount = 0
  Layout.LayoutMessages(factory, contentFrame, messages3, 400)
  local countAfterFirst = createCount

  createCount = 0
  Layout.LayoutMessages(factory, contentFrame, messages3, 400)
  local countAfterSecond = createCount

  assert(
    countAfterSecond == 0,
    "expected zero new CreateFrame calls on re-render, got "
      .. countAfterSecond
      .. " (first render: "
      .. countAfterFirst
      .. ")"
  )

  -- TEST 2: Growing message count only creates frames for new messages
  local messages5 = {
    messages3[1],
    messages3[2],
    messages3[3],
    {
      direction = "in",
      kind = "user",
      text = "extra msg 1",
      sentAt = 1003,
      playerName = "Arthas",
    },
    {
      direction = "out",
      kind = "user",
      text = "extra msg 2",
      sentAt = 1004,
      playerName = "Me",
    },
  }

  createCount = 0
  Layout.LayoutMessages(factory, contentFrame, messages5, 400)
  -- Should create only frames for the 2 additional messages, not all 5
  assert(
    countAfterFirst > 0 and createCount < countAfterFirst,
    "expected fewer CreateFrame calls for 5 messages after 3 were pooled, got "
      .. createCount
      .. " vs first-render "
      .. countAfterFirst
  )

  -- TEST 3: Shrinking message count hides excess frames
  createCount = 0
  Layout.LayoutMessages(factory, contentFrame, { messages3[1] }, 400)
  assert(createCount == 0, "expected zero new CreateFrame calls when shrinking, got " .. createCount)
end
