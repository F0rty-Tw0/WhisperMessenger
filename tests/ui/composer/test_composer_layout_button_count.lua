local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ComposerLayout = require("WhisperMessenger.UI.Composer.ComposerLayout")

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

local function layoutParts()
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
  return parts
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_two_buttons_widen_the_box
  do
    local inputW = ComposerLayout.Compute(600, 1, 12, 2).inputW
    assert(inputW == 524, "two buttons leave a 524px box, got " .. tostring(inputW))
  end

  -- test_text_width_follows_the_count
  do
    local width = ComposerLayout.TextWidth(600, 2)
    assert(width == 508, "two buttons leave 508px of text, got " .. tostring(width))
  end

  -- test_missing_count_means_three
  do
    local inputW = ComposerLayout.Compute(600, 1, 12).inputW
    local textW = ComposerLayout.TextWidth(600)
    assert(inputW == 494 and textW == 478, "no count lays out three buttons, got " .. tostring(inputW) .. "/" .. tostring(textW))
  end

  -- test_apply_two_buttons_sizes_box_and_input
  do
    local parts = layoutParts()
    ComposerLayout.Apply(parts, 600, 1, 12, 2)
    assert(parts.box.width == 524 and parts.input.width == 524, "box and input take the freed width, got " .. tostring(parts.box.width))
  end

  -- test_apply_two_buttons_anchors_quick_reply_to_send
  do
    local parts = layoutParts()
    ComposerLayout.Apply(parts, 600, 1, 12, 2)
    local pt = lastPoint(parts.quickReplyButton, "RIGHT")
    assert(pt[2] == parts.sendButton and pt[3] == "LEFT" and pt[4] == -4, "quick reply sits next to send")
  end

  -- test_apply_three_buttons_anchors_quick_reply_to_emoji
  do
    local parts = layoutParts()
    ComposerLayout.Apply(parts, 600, 1, 12)
    assert(lastPoint(parts.quickReplyButton, "RIGHT")[2] == parts.emojiButton, "quick reply sits next to emoji")
  end

  Theme.SetPreset(previousPreset)
end
