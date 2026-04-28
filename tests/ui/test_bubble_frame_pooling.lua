local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")

local function collectBubbleFrames(contentFrame)
  local bubbles = {}

  for _, frame in ipairs(contentFrame._activeFrames or {}) do
    if frame._textFS ~= nil then
      table.insert(bubbles, frame)
    end
  end

  return bubbles
end

return function()
  -- TEST 0: BubbleFrame leaves bubble positioning to Layout
  do
    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, {
      direction = "in",
      kind = "user",
      text = "hello",
      sentAt = 1000,
      playerName = "Arthas",
    }, {
      paneWidth = 400,
      showIcon = false,
    })

    assert(bubble.frame.point == nil, "expected CreateBubble to leave bubble placement unset for Layout")
  end

  -- TEST 0.5: BubbleFrame converts plain URLs into clickable hyperlinks
  do
    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, {
      direction = "in",
      kind = "user",
      text = "Visit https://example.com/docs for details.",
      sentAt = 1000,
      playerName = "Arthas",
    }, {
      paneWidth = 400,
      showIcon = false,
    })

    assert(
      bubble.text:GetText() == "Visit |cff71d5ff|Hurl:https://example.com/docs|hhttps://example.com/docs|h|r for details.",
      "expected BubbleFrame to render plain URLs as clickable hyperlinks"
    )
  end

  -- TEST 0.6: BubbleFrame keeps balanced trailing URL delimiters
  do
    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, {
      direction = "in",
      kind = "user",
      text = "Wiki https://en.wikipedia.org/wiki/Function_(mathematics).",
      sentAt = 1000,
      playerName = "Arthas",
    }, {
      paneWidth = 400,
      showIcon = false,
    })

    assert(
      bubble.text:GetText()
        == "Wiki |cff71d5ff|Hurl:https://en.wikipedia.org/wiki/Function_(mathematics)|hhttps://en.wikipedia.org/wiki/Function_(mathematics)|h|r.",
      "expected BubbleFrame to preserve balanced trailing ')' in URLs"
    )
  end

  -- TEST 0.7: BubbleFrame keeps IPv6 bracket delimiters in URLs
  do
    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, {
      direction = "in",
      kind = "user",
      text = "Server https://[2001:db8::1]/docs",
      sentAt = 1000,
      playerName = "Arthas",
    }, {
      paneWidth = 400,
      showIcon = false,
    })

    assert(
      bubble.text:GetText() == "Server |cff71d5ff|Hurl:https://[2001:db8::1]/docs|hhttps://[2001:db8::1]/docs|h|r",
      "expected BubbleFrame to preserve IPv6 brackets in URLs"
    )
  end

  -- TEST 0.8: BubbleFrame does not rewrite existing WoW hyperlinks
  do
    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local itemLink = "|cffffff00|Hitem:19019::::::::|h[Thunderfury]|h|r"
    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, {
      direction = "in",
      kind = "user",
      text = "Loot " .. itemLink .. " and https://example.com",
      sentAt = 1000,
      playerName = "Arthas",
    }, {
      paneWidth = 400,
      showIcon = false,
    })

    assert(
      bubble.text:GetText() == "Loot " .. itemLink .. " and |cff71d5ff|Hurl:https://example.com|hhttps://example.com|h|r",
      "expected BubbleFrame to preserve existing item hyperlinks while linkifying plain URLs"
    )
  end
  -- TEST 1: Layout owns final bubble placement for each alignment mode
  do
    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local messages = {
      {
        direction = "in",
        kind = "user",
        text = "incoming",
        sentAt = 1000,
        playerName = "Arthas",
      },
      {
        direction = "in",
        kind = "system",
        text = "system",
        sentAt = 1001,
      },
      {
        direction = "out",
        kind = "user",
        text = "outgoing",
        sentAt = 1002,
        playerName = "Me",
      },
    }

    Layout.LayoutMessages(factory, contentFrame, messages, 400)

    local bubbles = collectBubbleFrames(contentFrame)
    assert(#bubbles == 3, "expected three bubble frames after layout, got " .. tostring(#bubbles))

    assert(bubbles[1].point[1] == "TOPLEFT", "expected incoming bubble anchor TOPLEFT, got " .. tostring(bubbles[1].point[1]))
    assert(
      bubbles[1].point[4] == Layout.MESSAGE_EDGE_INSET,
      "expected incoming bubble inset " .. tostring(Layout.MESSAGE_EDGE_INSET) .. ", got " .. tostring(bubbles[1].point[4])
    )

    assert(bubbles[2].point[1] == "TOP", "expected system bubble anchor TOP, got " .. tostring(bubbles[2].point[1]))
    assert(bubbles[2].point[4] == 200, "expected system bubble centered at pane midpoint, got " .. tostring(bubbles[2].point[4]))

    assert(bubbles[3].point[1] == "TOPRIGHT", "expected outgoing bubble anchor TOPRIGHT, got " .. tostring(bubbles[3].point[1]))
    assert(
      bubbles[3].point[4] == -Layout.MESSAGE_EDGE_INSET,
      "expected outgoing bubble inset -" .. tostring(Layout.MESSAGE_EDGE_INSET) .. ", got " .. tostring(bubbles[3].point[4])
    )
  end

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

  -- TEST 2: Second render reuses frames (zero new CreateFrame calls)
  createCount = 0
  Layout.LayoutMessages(factory, contentFrame, messages3, 400)
  local countAfterFirst = createCount

  createCount = 0
  Layout.LayoutMessages(factory, contentFrame, messages3, 400)
  local countAfterSecond = createCount

  assert(
    countAfterSecond == 0,
    "expected zero new CreateFrame calls on re-render, got " .. countAfterSecond .. " (first render: " .. countAfterFirst .. ")"
  )

  -- TEST 3: Growing message count only creates frames for new messages
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
    "expected fewer CreateFrame calls for 5 messages after 3 were pooled, got " .. createCount .. " vs first-render " .. countAfterFirst
  )

  -- TEST 4: Shrinking message count hides excess frames
  createCount = 0
  Layout.LayoutMessages(factory, contentFrame, { messages3[1] }, 400)
  assert(createCount == 0, "expected zero new CreateFrame calls when shrinking, got " .. createCount)
end
