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
    local input, emoji, send = composer.box, composer.emojiButton, composer.sendButton

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
    local inputPoint = lastPoint(composer.box, "BOTTOMLEFT")
    assert(inputPoint[4] == Theme.LAYOUT.COMPOSER_GUTTER, key .. ": input sits in the gutter")
  end

  -- test_compute_grows_input_but_keeps_buttons
  do
    Theme.SetPreset("wow_default")
    local ComposerLayout = require("WhisperMessenger.UI.Composer.ComposerLayout")
    local one = ComposerLayout.Compute(PANE_WIDTH)
    assert(one.inputH == 28 and one.sendBottom == 9, "one row keeps today's geometry")
    local three = ComposerLayout.Compute(PANE_WIDTH, 3, 12)
    assert(three.inputH == 52, "3 rows of 12 grow the input to 52, got " .. tostring(three.inputH))
    assert(three.sendBottom == 9, "buttons stay put, got " .. tostring(three.sendBottom))
    assert(three.textInsetY == 8, "vertical inset centers one line, got " .. tostring(three.textInsetY))
    assert(three.textH == 36, "text viewport is 3 rows of 12, got " .. tostring(three.textH))
    local two = ComposerLayout.Compute(PANE_WIDTH, 2, 16)
    assert(two.inputH == 44 and two.textInsetY == 6, "2 rows of 16: 44 tall, inset 6")
    assert(ComposerLayout.TextWidth(PANE_WIDTH) == 478, "text width is box minus both insets")
  end

  -- test_compute_gives_the_viewport_slack_above_and_below_the_rows
  do
    Theme.SetPreset("wow_default")
    local ComposerLayout = require("WhisperMessenger.UI.Composer.ComposerLayout")
    local slack = ComposerLayout.TEXT_SLACK_Y
    assert(slack == 3, "viewport slack is 3px, got " .. tostring(slack))
    local three = ComposerLayout.Compute(PANE_WIDTH, 3, 12)
    assert(three.textSlackY == slack, "slack is the constant when the inset has room, got " .. tostring(three.textSlackY))
    assert(three.viewportY == three.textInsetY - slack, "viewport starts slack above the text, got " .. tostring(three.viewportY))
    assert(three.viewportH == three.textH + 2 * slack, "viewport is the rows plus slack on both sides, got " .. tostring(three.viewportH))
  end

  -- test_compute_caps_the_slack_at_the_inset_so_the_viewport_stays_in_the_box
  do
    Theme.SetPreset("wow_default")
    local ComposerLayout = require("WhisperMessenger.UI.Composer.ComposerLayout")
    local tall = ComposerLayout.Compute(PANE_WIDTH, 1, 24)
    assert(tall.textInsetY == 2, "a 24px line leaves a 2px inset, got " .. tostring(tall.textInsetY))
    assert(tall.textSlackY == 2 and tall.viewportY == 0, "slack shrinks to the inset, got " .. tostring(tall.textSlackY))
    assert(tall.viewportH == 28, "viewport fills the 1-row box, got " .. tostring(tall.viewportH))
  end

  -- test_apply_sizes_box_and_insets_the_scroll_frame
  do
    Theme.SetPreset("wow_default")
    local ComposerLayout = require("WhisperMessenger.UI.Composer.ComposerLayout")
    local factory = FakeUI.NewFactory()
    local pane = factory.CreateFrame("Frame", "pane", nil)
    local function mk()
      return factory.CreateFrame("Frame", nil, pane)
    end
    local parts = {
      pane = pane,
      box = mk(),
      scroll = mk(),
      input = mk(),
      sendButton = mk(),
      emojiButton = mk(),
      emojiIcon = mk(),
      quickReplyButton = mk(),
    }
    parts.quickReplyButton.icon = mk()
    ComposerLayout.Apply(parts, PANE_WIDTH, 3, 12)
    assert(lastPoint(parts.box, "BOTTOMLEFT"), "box is positioned")
    assert(parts.box.width == 494 and parts.box.height == 52, "box sized 494x52")
    local top = lastPoint(parts.scroll, "TOPLEFT")
    assert(top and top[2] == parts.box and top[5] == -5, "scroll frame starts 5px into the box, got " .. tostring(top and top[5]))
    assert(parts.scroll.height == 42, "scroll frame is 3 rows of 12 plus 3px slack each side, got " .. tostring(parts.scroll.height))
    assert(parts.input.width == 494, "input takes the box width")
    local ins = parts.input.textInsets
    assert(ins and ins[1] == 8 and ins[2] == 8 and ins[3] == 3 and ins[4] == 3, "input insets 8,8,3,3")
    assert(-top[5] + ins[3] == 8, "text top stays 8px below the box top")
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_composer_layout")
end
