local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

local WORD = string.rep("x", 150)
-- Each 150-byte word fills its own 255-byte part.
local FOUR_PARTS = table.concat({ WORD, WORD, WORD, WORD }, " ")
local FIVE_PARTS = FOUR_PARTS .. " " .. WORD

local function build(channel, options)
  options = options or {}
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local contact = { conversationKey = "me::" .. channel .. "::arthas", displayName = "Arthas", channel = channel }
  local saved, typed = {}, {}
  local composer = Composer.Create(factory, parent, contact, function() end, nil, nil, function(_contact, text)
    table.insert(typed, text)
  end, {
    onDraftChanged = function(conversationKey, text)
      table.insert(saved, { key = conversationKey, text = text })
    end,
    getQuickReplies = options.getQuickReplies,
  })
  composer.setMaxBytes(channel)
  return composer, saved, typed
end

-- WoW fires OnTextChanged from SetText; emulate that.
local function fireOnSetText(input)
  local rawSetText = input.SetText
  input.SetText = function(self, text)
    rawSetText(self, text)
    self.scripts.OnTextChanged(self)
  end
end

-- The player typing or pasting: text and cursor change, then OnTextChanged.
local function type_(composer, text, cursor)
  composer.input.text = text
  composer.input.cursorPosition = cursor or #text
  composer.input.scripts.OnTextChanged(composer.input)
end

local function pickQuickReply(composer)
  composer.quickReplyButton.scripts.OnClick(composer.quickReplyButton)
  local row = composer.quickReplyPicker.rows[1]
  row.scripts.OnClick(row)
end

return function()
  -- test_group_input_holds_one_255_byte_message
  do
    local composer = build("PARTY")
    composer.input:Insert(string.rep("a", 300))
    local length = #composer.input:GetText()
    assert(composer.input.maxBytes == 256, "group cap 256, got " .. tostring(composer.input.maxBytes))
    assert(length == 255, "group input should hold a full 255-byte message, got " .. tostring(length))
  end

  -- test_wow_whisper_input_cap_is_800
  do
    local composer = build("WOW")
    composer.input:Insert(string.rep("a", 900))
    assert(composer.input.maxBytes == 800, "WoW whisper cap 800, got " .. tostring(composer.input.maxBytes))
    assert(#composer.input:GetText() == 799, "whisper input holds 799 bytes")
  end

  -- test_bnet_whisper_input_cap_is_800
  do
    local composer = build("BN")
    assert(composer.input.maxBytes == 800, "Battle.net whisper cap 800, got " .. tostring(composer.input.maxBytes))
  end

  -- test_four_part_whisper_is_accepted
  do
    local composer, saved = build("WOW")
    type_(composer, FOUR_PARTS)
    assert(composer.input:GetText() == FOUR_PARTS, "4-part text stays")
    assert(saved[#saved].text == FOUR_PARTS, "4-part text saved as draft")
  end

  -- test_five_part_paste_is_refused_with_text_and_cursor_restored
  do
    local composer = build("WOW")
    type_(composer, FOUR_PARTS, 10)
    fireOnSetText(composer.input)
    type_(composer, FIVE_PARTS)
    assert(composer.input:GetText() == FOUR_PARTS, "5-part text undone to the last text that fit")
    assert(composer.input:GetCursorPosition() == 10, "cursor restored, got " .. tostring(composer.input:GetCursorPosition()))
  end

  -- test_refused_change_never_saves_draft_or_signals_typing
  do
    local composer, saved, typed = build("WOW")
    type_(composer, FOUR_PARTS)
    local savedBefore, typedBefore = #saved, #typed
    fireOnSetText(composer.input)
    type_(composer, FIVE_PARTS)
    assert(#saved == savedBefore, "refused change saves no draft")
    assert(#typed == typedBefore, "refused change sends no typing ping")
  end

  -- test_group_composer_does_not_count_parts
  do
    local composer, saved = build("GUILD")
    type_(composer, FIVE_PARTS)
    assert(composer.input:GetText() == FIVE_PARTS, "group text is left to the byte cap")
    assert(saved[#saved].text == FIVE_PARTS, "group draft saved as before")
  end

  -- test_loaded_draft_is_the_restore_point
  do
    local composer = build("WOW")
    composer.loadDraft("hello")
    type_(composer, FIVE_PARTS)
    assert(composer.input:GetText() == "hello", "refusal restores the loaded draft")
  end

  -- test_switching_channel_changes_the_cap
  do
    local composer = build("PARTY")
    composer.setMaxBytes("WOW")
    assert(composer.input.maxBytes == 800, "whisper raises the cap")
    composer.setMaxBytes("RAID")
    assert(composer.input.maxBytes == 256, "group lowers the cap")
  end

  -- test_quick_reply_respects_whisper_cap
  do
    local composer = build("WOW", {
      getQuickReplies = function()
        return { "hello" }
      end,
    })
    local long = string.rep("x", 400)
    composer.input:SetText(long)
    pickQuickReply(composer)
    assert(composer.input:GetText() == long .. "hello", "reply fits a long whisper")
  end

  -- test_quick_reply_respects_group_cap_after_switch
  do
    local composer = build("WOW", {
      getQuickReplies = function()
        return { "hello" }
      end,
    })
    composer.setMaxBytes("PARTY")
    local full = string.rep("x", 252)
    composer.input:SetText(full)
    pickQuickReply(composer)
    assert(composer.input:GetText() == full, "reply past the group cap is not inserted")
  end

  -- test_emoji_respects_whisper_cap
  do
    local composer = build("WOW")
    local long = string.rep("x", 400)
    composer.input:SetText(long)
    composer.emojiButton.scripts.OnClick(composer.emojiButton)
    local button = composer.emojiPicker.buttons[1]
    button.scripts.OnClick(button)
    assert(#composer.input:GetText() > #long, "emoji fits a long whisper")
  end
end
