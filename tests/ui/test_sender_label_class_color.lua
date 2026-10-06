local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

-- Alpha is compared too: text_secondary is white at partial alpha, which
-- RGB alone can't tell apart from an unset colour.
local function assertColor(result, expected, label)
  local actual = { result.frame._wmSenderNameFS:GetTextColor() }
  local expectedAlpha = expected[4] or 1
  local matches = math.abs(actual[4] - expectedAlpha) < 0.001
  for i = 1, 3 do
    matches = matches and math.abs(actual[i] - expected[i]) < 0.001
  end
  assert(matches, label .. ": got " .. table.concat(actual, ", "))
end

return function()
  local previousClassColors = _G.RAID_CLASS_COLORS
  _G.RAID_CLASS_COLORS = {
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
  }

  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)
  local secondary = Theme.COLORS.text_secondary

  local function render(message, renderFactory, options)
    return SenderLabel.CreateSenderLabel(renderFactory or factory, contentFrame, message, 400, 0, options)
  end

  -- test_flag_on_colours_incoming_name_by_class
  do
    DisplayName.Configure({ classColorSenderNames = true })
    local result = render({ direction = "in", playerName = "Jaina", classTag = "MAGE" })
    assertColor(result, { 0.25, 0.78, 0.92 }, "incoming MAGE name should use the mage class colour")
  end

  -- test_flag_on_incoming_without_class_uses_secondary
  do
    DisplayName.Configure({ classColorSenderNames = true })
    local result = render({ direction = "in", playerName = "Jaina" })
    assertColor(result, secondary, "incoming name without a class should stay text_secondary")
  end

  -- test_flag_on_unknown_class_uses_secondary
  do
    DisplayName.Configure({ classColorSenderNames = true })
    local result = render({ direction = "in", playerName = "Jaina", classTag = "NOTACLASS" })
    assertColor(result, secondary, "incoming name with an unknown class should stay text_secondary")
  end

  -- test_flag_off_keeps_incoming_name_secondary
  do
    DisplayName.Configure({ classColorSenderNames = false })
    local result = render({ direction = "in", playerName = "Jaina", classTag = "MAGE" })
    assertColor(result, secondary, "flag off should keep the incoming name text_secondary")
  end

  -- test_flag_on_outgoing_you_stays_secondary
  do
    DisplayName.Configure({ classColorSenderNames = true })
    local result = render({ direction = "out", senderClassTag = "MAGE" })
    assertColor(result, secondary, "the outgoing 'You' label should stay text_secondary")
  end

  -- test_reused_frame_drops_class_colour_after_flag_turns_off
  -- With the flag off applyClassColor never runs, so only the per-render
  -- reset can clear the colour left on a pooled frame.
  do
    DisplayName.Configure({ classColorSenderNames = true })
    local shared = factory.CreateFrame("Frame", nil, contentFrame)
    local sameFrameFactory = {
      CreateFrame = function()
        return shared
      end,
    }
    local message = { direction = "in", playerName = "Jaina", classTag = "MAGE" }
    local first = render(message, sameFrameFactory)
    assertColor(first, { 0.25, 0.78, 0.92 }, "first render on the shared frame should be mage-coloured")
    DisplayName.Configure({ classColorSenderNames = false })
    local second = render(message, sameFrameFactory)
    assert(second.frame == first.frame, "expected the same frame on both renders")
    assertColor(second, secondary, "a reused frame should drop the class colour once the flag is off")
  end

  -- test_whisper_fallback_colours_name_without_class
  do
    DisplayName.Configure({ classColorSenderNames = true })
    local result = render({ direction = "in", playerName = "Jaina" }, nil, { senderFallbackClassTag = "MAGE" })
    assertColor(result, { 0.25, 0.78, 0.92 }, "incoming name without a class should use the whisper fallback class")
  end

  -- test_message_class_wins_over_whisper_fallback
  do
    DisplayName.Configure({ classColorSenderNames = true })
    local message = { direction = "in", playerName = "Garrosh", classTag = "WARRIOR" }
    local result = render(message, nil, { senderFallbackClassTag = "MAGE" })
    assertColor(result, { 0.78, 0.61, 0.43 }, "the message's own class should win over the fallback")
  end

  -- test_flag_off_ignores_whisper_fallback
  do
    DisplayName.Configure({ classColorSenderNames = false })
    local result = render({ direction = "in", playerName = "Jaina" }, nil, { senderFallbackClassTag = "MAGE" })
    assertColor(result, secondary, "flag off should keep the name text_secondary despite a fallback")
  end

  DisplayName.Configure({ classColorSenderNames = false })
  _G.RAID_CLASS_COLORS = previousClassColors
end
