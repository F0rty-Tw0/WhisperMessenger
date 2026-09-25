local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer")

local PANE_WIDTH = 600

-- Last SetPoint for `anchor` (WoW replaces per anchor).
local function lastPoint(region, anchor)
  local found
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      found = pt
    end
  end
  return found
end

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(PANE_WIDTH, Theme.COMPOSER_HEIGHT)
  return Composer.Create(factory, parent, { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }, function() end)
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_modern_composer_is_compact_with_centered_buttons
  do
    Theme.SetPreset("wow_default")
    local layout = Theme.LAYOUT
    local gutter, size, gap = layout.COMPOSER_GUTTER, layout.COMPOSER_BUTTON_SIZE, layout.COMPOSER_BUTTON_GAP
    assert(gutter == 8 and size == 26 and gap == 4, "compact modern composer metrics live in Theme.LAYOUT")
    assert(Theme.COMPOSER_HEIGHT == 44, "modern composer strip is 44px, got " .. tostring(Theme.COMPOSER_HEIGHT))

    local composer = build()
    local input, emoji, send = composer.input, composer.emojiButton, composer.sendButton

    local inputPoint = lastPoint(input, "BOTTOMLEFT")
    assert(inputPoint[4] == gutter, "left gutter is " .. gutter .. ", got " .. tostring(inputPoint[4]))
    assert(inputPoint[5] == gutter, "bottom gutter is " .. gutter .. ", got " .. tostring(inputPoint[5]))
    assert(input.height == 28, "input fills the strip minus both gutters, got " .. tostring(input.height))
    assert(Theme.COMPOSER_HEIGHT - gutter - input.height == gutter, "top gutter equals bottom gutter (input vertically centered)")

    local sendPoint = lastPoint(send, "BOTTOMRIGHT")
    local centeredBottom = gutter + (input.height - size) / 2
    assert(sendPoint[4] == -gutter, "send sits in the right gutter")
    assert(sendPoint[5] == centeredBottom, "send vertically centered on the input, got " .. tostring(sendPoint[5]))
    assert(send.width == size and send.height == size, "send is a square button")
    assert(emoji.width == size and emoji.height == size, "emoji matches the send size")

    local emojiPoint = lastPoint(emoji, "RIGHT")
    assert(emojiPoint[3] == "LEFT" and emojiPoint[4] == -gap, "emoji -> send gap is " .. gap)

    local quick = composer.quickReplyButton
    assert(quick.width == size and quick.height == size, "quick reply button matches the emoji size")
    local quickPoint = lastPoint(quick, "RIGHT")
    assert(quickPoint[2] == emoji and quickPoint[3] == "LEFT" and quickPoint[4] == -gap, "quick reply -> emoji gap is " .. gap)

    local inputRight = gutter + input.width
    local quickLeft = PANE_WIDTH - gutter - size - gap - size - gap - size
    assert(quickLeft - inputRight == gap, "input -> quick reply gap is " .. gap .. ", got " .. tostring(quickLeft - inputRight))
  end

  -- test_every_preset_uses_the_compact_composer
  for _, key in ipairs(Theme.ListPresets()) do
    Theme.SetPreset(key)
    assert(Theme.COMPOSER_HEIGHT == 44, key .. ": 44px composer strip, got " .. tostring(Theme.COMPOSER_HEIGHT))
    local composer = build()
    local inputPoint = lastPoint(composer.input, "BOTTOMLEFT")
    assert(inputPoint[4] == Theme.LAYOUT.COMPOSER_GUTTER, key .. ": input sits in the gutter")
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_composer_layout")
end
