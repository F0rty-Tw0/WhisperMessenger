local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

local function build(entries, onSend, withoutHistory)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local selectedContact = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }
  local t = { saved = {}, typed = {}, asked = 0, entries = entries or { "e1", "e2" } }
  local options = {
    onDraftChanged = function(conversationKey, text)
      table.insert(t.saved, { key = conversationKey, text = text })
    end,
  }
  if not withoutHistory then
    options.getSentHistory = function(fits)
      t.asked = t.asked + 1
      t.fits = fits
      return t.entries
    end
  end
  local onTyping = function(_contact, text)
    table.insert(t.typed, text)
  end
  t.composer = Composer.Create(factory, parent, selectedContact, onSend or function() end, nil, nil, onTyping, options)
  t.input = t.composer.input
  t.up = function()
    t.input.scripts.OnKeyDown(t.input, "UP")
  end
  t.down = function()
    t.input.scripts.OnKeyDown(t.input, "DOWN")
  end
  return t
end

local function noTypingNotice(typed)
  for _, text in ipairs(typed) do
    if text ~= "" then
      return false
    end
  end
  return true
end

-- WoW fires OnTextChanged from SetText; emulate that.
local function echoSetText(input)
  local rawSetText = input.SetText
  input.SetText = function(self, text)
    rawSetText(self, text)
    self.scripts.OnTextChanged(self)
  end
end

return function()
  -- test_recall_saves_the_draft
  do
    local t = build()
    t.up()
    local last = t.saved[#t.saved]
    assert(last and last.key == "me::WOW::arthas" and last.text == "e1", "a recall saves the draft")
  end

  -- test_recall_sends_no_typing_notice
  do
    local t = build()
    t.up()
    t.up()
    assert(noTypingNotice(t.typed), "stepping through history sends no typing notice")
  end

  -- test_editing_a_recalled_line_sends_the_notice
  do
    local t = build()
    t.up()
    t.input:SetText("e1!")
    t.input.scripts.OnTextChanged(t.input)
    assert(t.typed[#t.typed] == "e1!", "editing the recalled line sends the typing notice")
  end

  local function echoedTwoUps()
    local t = build()
    echoSetText(t.input)
    t.up()
    t.up()
    return t
  end

  -- test_in_game_echo_still_sends_no_notice
  do
    local t = echoedTwoUps()
    assert(noTypingNotice(t.typed), "the SetText echo sends no typing notice")
  end

  -- test_in_game_echo_keeps_the_recall
  do
    local t = echoedTwoUps()
    assert(t.input:GetText() == "e2", "the echo does not end the recall")
  end

  -- test_edit_back_to_the_recalled_line_still_ends_the_recall
  do
    local t = build()
    t.up()
    t.input:SetText("e1x")
    t.input.scripts.OnTextChanged(t.input)
    t.input:SetText("e1")
    t.input.scripts.OnTextChanged(t.input)
    t.up()
    assert(t.input:GetText() == "e1", "an edit ends the recall even when the text comes back")
  end

  -- test_recall_hides_the_placeholder
  do
    local t = build()
    t.up()
    assert(t.composer.placeholder.shown == false, "placeholder hidden for a recalled line")
  end

  local function upThenDown()
    local t = build()
    t.up()
    t.down()
    return t
  end

  -- test_down_at_newest_clears_the_box
  do
    local t = upThenDown()
    assert(t.input:GetText() == "", "Down at the newest clears the box")
  end

  -- test_down_at_newest_shows_the_placeholder
  do
    local t = upThenDown()
    assert(t.composer.placeholder.shown == true, "placeholder back on the empty box")
  end

  -- test_down_at_newest_clears_the_draft
  do
    local t = upThenDown()
    assert(t.saved[#t.saved].text == "", "the draft is cleared too")
  end

  -- test_chat_switch_ends_the_recall
  do
    local t = build()
    t.up()
    t.composer.loadDraft("e1")
    t.up()
    assert(t.input:GetText() == "e1", "a chat switch ends the recall")
  end

  -- test_send_then_up_starts_a_fresh_recall
  do
    local t = build(nil, function()
      return true
    end)
    t.up()
    t.input.scripts.OnEnterPressed(t.input)
    t.entries = { "e1", "older" }
    t.up()
    assert(t.input:GetText() == "e1" and t.asked == 2, "Up after a send starts a fresh recall")
  end

  -- test_escape_keeps_the_recall
  do
    local t = build()
    t.up()
    t.input.scripts.OnEscapePressed(t.input)
    t.up()
    assert(t.input:GetText() == "e2", "Esc keeps the recall")
  end

  -- test_recall_uses_the_group_chat_cap
  do
    local t = build()
    t.composer.setMaxBytes("PARTY")
    t.up()
    assert(t.fits(string.rep("a", 256)) == false, "group chat cap applies")
  end

  -- test_recall_fit_check_follows_a_chat_switch
  do
    local t = build()
    t.composer.setMaxBytes("PARTY")
    t.up()
    t.composer.setMaxBytes("WOW")
    assert(t.fits(string.rep("a", 256)) == true, "whisper cap applies after a switch")
  end

  -- test_no_history_option_leaves_up_alone
  do
    local t = build(nil, nil, true)
    t.up()
    assert(t.input:GetText() == "", "no history option leaves Up alone")
  end
end
