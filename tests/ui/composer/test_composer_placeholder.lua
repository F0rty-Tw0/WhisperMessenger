local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer")

local PRESETS = { "wow_default", "elvui_dark", "plumber_warm", "jade_dark", "wow_native" }
-- Minimum luminance gap between the blended placeholder and the input fill.
local MIN_CONTRAST = 0.3

local function luminance(c)
  return 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]
end

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, Theme.COMPOSER_HEIGHT)
  return Composer.Create(factory, parent, { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }, function() end)
end

return function()
  local previousPreset = Theme.GetPreset()

  for _, key in ipairs(PRESETS) do
    Theme.SetPreset(key)
    local composer = build()
    local placeholder = composer.placeholder

    -- test_placeholder_draws_above_input_fill: the rounded fill lives on the
    -- input frame, which renders above every region of the pane. A pane
    -- FontString is hidden behind it, so the placeholder must be the input's.
    assert(placeholder:GetParent() == composer.input, key .. ": placeholder must be parented to the input")

    -- test_placeholder_contrasts_with_input_fill
    local fg = placeholder.textColor
    local bg = Theme.COLORS.bg_message_input or Theme.COLORS.bg_input
    local alpha = fg[4] or 1
    local blended = luminance(fg) * alpha + luminance(bg) * (1 - alpha)
    local gap = math.abs(blended - luminance(bg))
    assert(gap >= MIN_CONTRAST, key .. ": placeholder too close to input fill, contrast " .. string.format("%.2f", gap))
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_composer_placeholder")
end
