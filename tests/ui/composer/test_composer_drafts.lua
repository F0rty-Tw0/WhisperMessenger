local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

local function build(onSend, onTyping)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local selectedContact = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }
  local saved = {}
  local composer = Composer.Create(factory, parent, selectedContact, onSend or function() end, nil, nil, onTyping, {
    onDraftChanged = function(conversationKey, text)
      table.insert(saved, { key = conversationKey, text = text })
    end,
  })
  return composer, selectedContact, saved
end

return function()
  -- test_typing_saves_draft_for_selected_conversation
  do
    local composer, _, saved = build()
    composer.input:SetText("half typed")
    composer.input.scripts.OnTextChanged(composer.input)
    assert(#saved == 1, "text change should save a draft")
    assert(saved[1].key == "me::WOW::arthas" and saved[1].text == "half typed", "draft saved under the selected conversation")
  end

  -- test_no_draft_saved_without_a_selected_conversation
  do
    local composer, selectedContact, saved = build()
    selectedContact.conversationKey = nil
    composer.input:SetText("orphan")
    composer.input.scripts.OnTextChanged(composer.input)
    assert(#saved == 0, "no conversation selected -> nothing to save")
  end

  -- test_load_draft_replaces_input_and_updates_placeholder
  do
    local composer = build()
    composer.loadDraft("welcome back")
    assert(composer.input:GetText() == "welcome back", "loadDraft puts the draft in the input")
    assert(composer.placeholder.shown == false, "placeholder hidden when a draft is loaded")
    composer.loadDraft(nil)
    assert(composer.input:GetText() == "", "loading no draft empties the input")
    assert(composer.placeholder.shown == true, "placeholder shown for an empty input")
  end

  -- test_load_draft_does_not_resave_or_signal_typing
  do
    local typed = {}
    local composer, _, saved = build(nil, function(_contact, text)
      table.insert(typed, text)
    end)
    -- WoW fires OnTextChanged from SetText; emulate that for this test.
    local input = composer.input
    local rawSetText = input.SetText
    input.SetText = function(self, text)
      rawSetText(self, text)
      self.scripts.OnTextChanged(self)
    end
    composer.loadDraft("from before")
    assert(#saved == 0, "loading a draft must not write it back")
    assert(#typed == 1 and typed[1] == "", "loading a draft only stops any typing signal, never starts one")
  end

  -- test_accepted_send_clears_the_draft
  do
    local composer, _, saved = build(function()
      return true
    end)
    composer.input:SetText("hello")
    composer.input.scripts.OnEnterPressed(composer.input)
    local last = saved[#saved]
    assert(last and last.key == "me::WOW::arthas" and last.text == "", "sending clears the conversation's draft")
  end

  -- test_rejected_send_keeps_the_draft
  do
    local composer, _, saved = build(function()
      return false
    end)
    composer.input:SetText("hello")
    composer.input.scripts.OnEnterPressed(composer.input)
    assert(#saved == 0, "a rejected send leaves the draft alone")
    assert(composer.input:GetText() == "hello", "a rejected send keeps the text")
  end
end
