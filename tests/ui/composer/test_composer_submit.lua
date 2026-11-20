local FakeUI = require("tests.helpers.fake_ui")
local Composer = require("WhisperMessenger.UI.Composer")
local ComposerSubmit = require("WhisperMessenger.UI.Composer.ComposerSubmit")

local CONTACT = { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }

local function build(options)
  options = options or {}
  local calls = { sent = 0, cleared = 0, drafts = {}, afterClear = 0 }
  local input = { text = options.text or "hello" }
  function input:GetText()
    return self.text
  end
  function input:SetText(text)
    self.text = text
  end
  local submit = ComposerSubmit.Create({
    input = input,
    replies = {
      current = function()
        return nil
      end,
      clear = function()
        calls.cleared = calls.cleared + 1
      end,
    },
    limit = { remember = function() end },
    sendFocus = { afterSend = function() end },
    selectedContact = CONTACT,
    onSend = function()
      calls.sent = calls.sent + 1
      return options.accepted
    end,
    onDraftChanged = function(key, text)
      calls.drafts[#calls.drafts + 1] = { key = key, text = text }
    end,
    isDisabled = function()
      return options.disabled == true
    end,
    afterClear = function()
      calls.afterClear = calls.afterClear + 1
    end,
  })
  return submit, input, calls
end

-- A real composer on fake frames.
local function buildComposer()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)

  return Composer.Create(factory, parent, CONTACT, function() end, nil, nil, nil, nil)
end

return function()
  -- test_disabled_composer_sends_nothing
  do
    local submit, input, calls = build({ disabled = true })
    submit()
    assert(calls.sent == 0, "a disabled composer sends nothing")
    assert(input.text == "hello", "and keeps the text")
  end

  -- test_empty_text_sends_nothing
  do
    local submit, _, calls = build({ text = "" })
    submit()
    assert(calls.sent == 0, "empty text sends nothing")
  end

  -- test_accepted_send_clears_and_reports
  do
    local submit, input, calls = build()
    submit()
    assert(calls.sent == 1, "the message goes out")
    assert(input.text == "", "the input empties")
    assert(#calls.drafts == 1 and calls.drafts[1].text == "", "the draft empties")
    assert(calls.afterClear == 1, "afterClear runs once, got " .. calls.afterClear)
  end

  -- test_refused_send_keeps_the_text
  do
    local submit, input, calls = build({ accepted = false })
    submit()
    assert(calls.sent == 1, "the send was tried")
    assert(input.text == "hello", "refused text stays")
    assert(calls.afterClear == 0, "nothing cleared")
  end

  -- test_composer_submit_is_what_enter_runs
  do
    local composer = buildComposer()
    assert(composer.submit ~= nil, "the composer exposes submit")
    assert(composer.submit == composer.input:GetScript("OnEnterPressed"), "submit is the Enter script itself")
  end

  print("PASS: test_composer_submit")
end
