local FakeUI = require("tests.helpers.fake_ui")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

-- A whisper tagged by an addon greeting shows "(Sent by <AddonName>)" in its
-- sender label.

local function shownTexts(frame)
  local texts = {}
  for _, child in ipairs(frame.children or {}) do
    if type(child.text) == "string" and child.shown ~= false then
      texts[#texts + 1] = child.text
    end
  end
  return table.concat(texts, "|")
end

local function incoming(addonGreeting)
  return { direction = "in", kind = "user", text = "Hi!", sentAt = 1000, playerName = "Crafter", addonGreeting = addonGreeting }
end

return function()
  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  -- test_tagged_whisper_shows_sent_by_badge
  do
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, incoming("CraftScan"), 400, 0)
    local texts = shownTexts(result.frame)
    assert(string.find(texts, "(Sent by CraftScan)", 1, true), "badge shows the addon name, got: " .. texts)
  end

  -- test_untagged_whisper_has_no_badge
  do
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, incoming(nil), 400, 0)
    local texts = shownTexts(result.frame)
    assert(not string.find(texts, "Sent by", 1, true), "no badge without a greeting, got: " .. texts)
  end

  -- test_badge_uses_the_tag_colour
  do
    local Theme = require("WhisperMessenger.UI.Theme")
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, incoming("CraftScan"), 400, 0)
    local badge = result.frame._wmSenderGreetingFS
    assert(badge ~= nil, "badge FontString cached on the label frame")
    local r, g, b = badge:GetTextColor()
    assert(r == Theme.TAG_GOLD[1] and g == Theme.TAG_GOLD[2] and b == Theme.TAG_GOLD[3], "badge uses the tag gold")
  end

  -- test_reused_frame_drops_the_badge
  -- Pooled label frames keep their FontStrings, so the next message on the
  -- same frame must hide the badge, incoming or outgoing.
  do
    local shared = factory.CreateFrame("Frame", nil, contentFrame)
    local sameFrameFactory = {
      CreateFrame = function()
        return shared
      end,
    }
    local outgoing = { direction = "out", kind = "user", text = "Thanks", sentAt = 1001 }
    for _, following in ipairs({ incoming(nil), outgoing }) do
      SenderLabel.CreateSenderLabel(sameFrameFactory, contentFrame, incoming("CraftScan"), 400, 0)
      local result = SenderLabel.CreateSenderLabel(sameFrameFactory, contentFrame, following, 400, 0)
      local texts = shownTexts(result.frame)
      assert(not string.find(texts, "Sent by", 1, true), following.direction .. " message on a reused frame shows no badge, got: " .. texts)
    end
  end
end
