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

  -- test_mention_bubble_colours_the_player_name_in_class_colour
  local saved = { _G.UnitName, _G.UnitClass, _G.RAID_CLASS_COLORS }
  rawset(_G, "UnitName", function()
    return "Arthas"
  end)
  rawset(_G, "UnitClass", function()
    return "Paladin", "PALADIN"
  end)
  _G.RAID_CLASS_COLORS = { PALADIN = { r = 244 / 255, g = 140 / 255, b = 186 / 255 } }
  local named = BubbleFrame.CreateBubble(factory, parent, { text = "hi Arthas", kind = "user", direction = "in", mention = true })
  local shown = named.frame._textFS.text
  assert(shown == "hi |cfff48cbaArthas|r", "mention text: " .. tostring(shown))

  -- test_plain_bubble_text_is_not_coloured
  local unnamed = BubbleFrame.CreateBubble(factory, parent, { text = "hi Arthas", kind = "user", direction = "in" })
  assert(unnamed.frame._textFS.text == "hi Arthas", "no colour without the mention flag")
  rawset(_G, "UnitName", saved[1])
  rawset(_G, "UnitClass", saved[2])
  _G.RAID_CLASS_COLORS = saved[3]
end
