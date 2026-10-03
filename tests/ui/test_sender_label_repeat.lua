local FakeUI = require("tests.helpers.fake_ui")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

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
end
