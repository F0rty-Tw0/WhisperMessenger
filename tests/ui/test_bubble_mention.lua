local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Theme = require("WhisperMessenger.UI.Theme")

-- A group line that names the player gets an accent-tinted bubble.
return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  local function fillColor(bubble)
    return bubble.bgFills[1].color
  end

  local plain = BubbleFrame.CreateBubble(factory, parent, { text = "hi all", kind = "user", direction = "in" })
  local mention = BubbleFrame.CreateBubble(factory, parent, { text = "hi Arthas", kind = "user", direction = "in", mention = true })

  -- test_plain_incoming_bubble_keeps_theme_colour
  local base = Theme.COLORS.bg_bubble_in
  assert(fillColor(plain)[1] == base[1] and fillColor(plain)[3] == base[3], "plain bubble unchanged")

  -- test_mention_bubble_is_tinted_toward_the_accent
  local accent = Theme.COLORS.accent
  local tinted = fillColor(mention)
  local function distance(color)
    return math.abs(color[1] - accent[1]) + math.abs(color[2] - accent[2]) + math.abs(color[3] - accent[3])
  end
  assert(distance(tinted) < distance(fillColor(plain)), "mention bubble sits closer to the accent colour")

  -- test_pooled_bubble_drops_the_tint
  local reused = BubbleFrame.CreateBubble(factory, parent, { text = "later", kind = "user", direction = "in" })
  assert(fillColor(reused)[1] == base[1], "a fresh plain bubble is not tinted")
end
