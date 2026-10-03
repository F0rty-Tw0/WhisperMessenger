local FakeUI = require("tests.helpers.fake_ui")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")

-- A collapsed row shows how often the sender repeated the line.

local function labelTexts(frame)
  local texts = {}
  for _, child in ipairs(frame.children or {}) do
    if type(child.text) == "string" and child.shown ~= false then
      texts[#texts + 1] = child.text
    end
  end
  return table.concat(texts, "|")
end

local function incoming(repeatCount)
  return { direction = "in", kind = "user", text = "WTS boost", sentAt = 1000, lastSeenAt = 1060, repeatCount = repeatCount, playerName = "Spammer" }
end

return function()
  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  -- test_repeated_message_shows_counter
  do
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, incoming(3), 400, 0)
    local texts = labelTexts(result.frame)
    assert(string.find(texts, "×3", 1, true), "collapsed row shows ×3, got: " .. texts)
  end

  -- test_single_message_shows_no_counter
  do
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, incoming(nil), 400, 0)
    local texts = labelTexts(result.frame)
    assert(not string.find(texts, "×", 1, true), "a single message shows no counter, got: " .. texts)
  end

  -- test_repeat_inside_a_same_sender_run_keeps_its_label
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    frame:SetSize(400, 600)
    local first = { direction = "in", kind = "user", text = "hello", sentAt = 1000, playerName = "Spammer" }
    local repeated = { direction = "in", kind = "user", text = "WTS boost", sentAt = 1010, repeatCount = 3, playerName = "Spammer" }
    Layout.LayoutMessages(factory, frame, { first, repeated }, 400, {})
    local found = false
    for _, child in ipairs(frame.children or {}) do
      if string.find(labelTexts(child), "×3", 1, true) then
        found = true
      end
    end
    assert(found, "a collapsed row inside a same-sender run still shows ×3")

    local other = { direction = "in", kind = "user", text = "hi", sentAt = 1000, playerName = "Someone" }
    local estimate = Layout.EstimateRowHeight(first, repeated, 400, false)
    assert(estimate == Layout.EstimateRowHeight(other, repeated, 400, false), "the height estimate counts the label like a run start")
  end
end
