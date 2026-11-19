local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer")

local CONTACT = { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }

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

-- A 600px composer with wrapping text, a height recorder and a nav-change counter.
local function build(options)
  Fonts.Initialize("default")
  local factory = FakeUI.NewFactory({ wrap = true })
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 44)
  local env = { heights = {}, nav = 0, parent = parent }
  options = options or {}
  options.onHeightChanged = function(height)
    env.heights[#env.heights + 1] = height
  end
  options.onNavTargetsChanged = function()
    env.nav = env.nav + 1
  end
  env.composer = Composer.Create(factory, parent, CONTACT, function() end, nil, nil, nil, options)
  return env.composer, env
end

local function typeChars(composer, count)
  composer.input:SetText(("a"):rep(count))
  composer.input.scripts.OnTextChanged(composer.input, true)
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_emoji_button_shown_by_default
  do
    local composer = build()
    assert(composer.emojiButton:IsShown() == true, "the emoji button shows by default")
    assert(composer.box.width == 494, "three buttons leave a 494px box, got " .. tostring(composer.box.width))
  end

  -- test_saved_off_builds_without_the_button
  do
    local composer = build({ showEmojiButton = false })
    assert(not composer.emojiButton:IsShown(), "a saved off builds without the button")
  end

  -- test_saved_off_leaves_a_two_button_box
  do
    local composer = build({ showEmojiButton = false })
    assert(composer.box.width == 524, "two buttons leave a 524px box, got " .. tostring(composer.box.width))
  end

  -- test_saved_off_puts_quick_reply_next_to_send
  do
    local composer = build({ showEmojiButton = false })
    assert(lastPoint(composer.quickReplyButton, "RIGHT")[2] == composer.sendButton, "quick reply sits next to send")
  end

  -- test_hiding_closes_an_open_picker
  do
    local composer = build()
    composer.emojiButton.scripts.OnClick(composer.emojiButton)
    assert(composer.emojiPicker.frame:IsShown(), "precondition: the picker is open")
    composer.setEmojiButtonShown(false)
    assert(not composer.emojiPicker.frame:IsShown(), "hiding the button closes the picker")
  end

  -- test_hiding_widens_the_box
  do
    local composer = build()
    composer.setEmojiButtonShown(false)
    assert(not composer.emojiButton:IsShown(), "the button hides")
    assert(composer.box.width == 524, "the box takes the freed width, got " .. tostring(composer.box.width))
  end

  -- test_hiding_drops_a_wrapped_line_back_to_one_row
  do
    local composer, env = build()
    typeChars(composer, 70)
    assert(composer.getHeight() == 56, "precondition: 70 chars wrap to two rows, got " .. tostring(composer.getHeight()))
    composer.setEmojiButtonShown(false)
    assert(composer.getHeight() == 44, "the line fits one row again, got " .. tostring(composer.getHeight()))
    assert(env.heights[#env.heights] == 44, "the window hears the one-row height")
  end

  -- test_showing_again_shows_the_button
  do
    local composer = build({ showEmojiButton = false })
    composer.setEmojiButtonShown(true)
    assert(composer.emojiButton:IsShown(), "the button shows again")
  end

  -- test_showing_again_gives_the_width_back
  do
    local composer = build({ showEmojiButton = false })
    composer.setEmojiButtonShown(true)
    assert(composer.box.width == 494, "the box gives the width back, got " .. tostring(composer.box.width))
  end

  -- test_showing_again_wraps_the_line_again
  do
    local composer = build({ showEmojiButton = false })
    typeChars(composer, 70)
    assert(composer.getHeight() == 44, "precondition: 70 chars fit one row with two buttons")
    composer.setEmojiButtonShown(true)
    assert(composer.getHeight() == 56, "the line wraps again, got " .. tostring(composer.getHeight()))
  end

  -- test_same_value_is_ignored
  do
    local composer, env = build()
    composer.setEmojiButtonShown(true)
    assert(env.nav == 0 and #env.heights == 0, "showing a shown button does nothing")
  end

  -- test_each_change_tells_the_nav
  do
    local composer, env = build()
    composer.setEmojiButtonShown(false)
    composer.setEmojiButtonShown(true)
    assert(env.nav == 2, "each real change tells the nav, got " .. env.nav)
  end

  -- test_resize_while_hidden_keeps_two_buttons
  do
    local composer, env = build({ showEmojiButton = false })
    env.parent:SetSize(700, 44)
    composer.relayout(700)
    assert(composer.box.width == 624, "a resize keeps two buttons, got " .. tostring(composer.box.width))
  end

  -- test_lock_and_theme_keep_it_hidden
  do
    local composer = build({ showEmojiButton = false })
    composer.setEnabled(false)
    composer.setEnabled(true)
    composer.refreshTheme()
    assert(not composer.emojiButton:IsShown(), "lock and theme keep the button hidden")
    assert(composer.box.width == 524, "lock and theme keep two buttons, got " .. tostring(composer.box.width))
  end

  Theme.SetPreset(previousPreset)
end
