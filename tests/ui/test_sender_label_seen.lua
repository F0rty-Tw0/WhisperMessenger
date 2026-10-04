local FakeUI = require("tests.helpers.fake_ui")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local LayoutMessages = require("tests.helpers.layout_messages")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")

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
    LayoutMessages(factory, contentFrame, messages, 400, {})
    assert(countVisibleSeen(contentFrame) == 0, "group with an unseen tail shows no Seen")

    messages[4].seenAt = 35
    LayoutMessages(factory, contentFrame, messages, 400, {})
    assert(countVisibleSeen(contentFrame) == 1, "exactly one Seen once the newest group is fully seen")

    table.insert(messages, outgoing("e", 500, "w4", nil))
    LayoutMessages(factory, contentFrame, messages, 400, {})
    assert(countVisibleSeen(contentFrame) == 1, "Seen stays on the last seen group while a newer group waits")
  end

  local function countSeenScans(run)
    local original = Layout.SeenLabelIndex
    local calls = 0
    rawset(Layout, "SeenLabelIndex", function(...)
      calls = calls + 1
      return original(...)
    end)
    run()
    rawset(Layout, "SeenLabelIndex", original)
    return calls
  end

  -- test_layout_skips_seen_scan_when_receipts_are_off
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)
    local messages = { outgoing("a", 0, "w1", 5), outgoing("b", 1, "w2", 5), outgoing("c", 2, "w3", 5) }
    local off = countSeenScans(function()
      LayoutMessages(factory, contentFrame, messages, 400, { seenReceipts = false })
    end)
    assert(off == 0, "seenReceipts=false must skip the Seen scan, got " .. off)
    local on = countSeenScans(function()
      LayoutMessages(factory, contentFrame, messages, 400, { seenReceipts = true })
    end)
    assert(on == 1, "seenReceipts=true must scan once, got " .. on)
  end

  -- test_pane_scans_seen_only_for_whisper_conversations
  do
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(600, 420)
    local pane = ConversationPane.Create(factory, parent, nil, nil)
    local conversation = { messages = { outgoing("a", 0, "w1", 5) } }
    local group = countSeenScans(function()
      ConversationPane.Refresh(pane, { conversationKey = "guild::Stormwind", channel = "GUILD", displayName = "Guild" }, conversation)
    end)
    assert(group == 0, "group conversations must skip the Seen scan, got " .. group)
    local whisper = countSeenScans(function()
      ConversationPane.Refresh(pane, { conversationKey = "wow::WOW::arthas", channel = "WOW", displayName = "Arthas" }, conversation)
    end)
    assert(whisper > 0, "whisper conversations must scan for Seen")
  end
end
