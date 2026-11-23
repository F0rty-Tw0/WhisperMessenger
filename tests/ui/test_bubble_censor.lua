local FakeUI = require("tests.helpers.fake_ui")
local BubbleCensor = require("WhisperMessenger.UI.ChatBubble.BubbleCensor")

-- Runs fn with a stand-in C_ChatInfo whose GetChatLineText returns text.
local function withChatInfo(text, fn)
  local saved = rawget(_G, "C_ChatInfo")
  local uncensored = {}
  rawset(_G, "C_ChatInfo", {
    UncensorChatLine = function(lineID)
      uncensored[#uncensored + 1] = lineID
    end,
    GetChatLineText = function()
      return text
    end,
  })
  local ok, err = pcall(fn, uncensored)
  rawset(_G, "C_ChatInfo", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_reveal_swaps_in_the_uncensored_text
  withChatInfo("real words", function(uncensored)
    local message = { isCensored = true, lineID = 42, text = "****" }
    local revealed = 0
    local frame = {
      _wmMessage = message,
      _wmOnRevealCensored = function()
        revealed = revealed + 1
      end,
    }

    BubbleCensor.Reveal(frame)

    assert(message.isCensored == nil, "test_reveal_swaps_in_the_uncensored_text: censored flag cleared")
    assert(message.text == "real words", "test_reveal_swaps_in_the_uncensored_text: got " .. tostring(message.text))
    assert(uncensored[1] == 42, "test_reveal_swaps_in_the_uncensored_text: the chat line is uncensored")
    assert(revealed == 1, "test_reveal_swaps_in_the_uncensored_text: the transcript re-renders")
  end)

  -- test_reveal_ignores_a_plain_message
  withChatInfo("real words", function(uncensored)
    local message = { lineID = 42, text = "hello" }
    local revealed = 0
    BubbleCensor.Reveal({
      _wmMessage = message,
      _wmOnRevealCensored = function()
        revealed = revealed + 1
      end,
    })

    assert(message.text == "hello" and #uncensored == 0 and revealed == 0, "test_reveal_ignores_a_plain_message: nothing changes")
  end)

  -- test_apply_label_shows_the_hint_for_a_censored_message
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Button", nil, nil)
    local textFS = frame:CreateFontString(nil, "OVERLAY")

    local extra = BubbleCensor.ApplyLabel(frame, textFS, { isCensored = true, text = "****" })

    assert(extra == 12, "test_apply_label_shows_the_hint_for_a_censored_message: extra height " .. tostring(extra))
    assert(frame._censoredLabel ~= nil, "test_apply_label_shows_the_hint_for_a_censored_message: label created")
    assert(frame._censoredLabel.text == "(click to reveal)", "test_apply_label_shows_the_hint_for_a_censored_message: label text")
    assert(frame._censoredLabel.shown == true, "test_apply_label_shows_the_hint_for_a_censored_message: label shown")
  end

  -- test_apply_label_hides_the_hint_for_a_plain_message
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Button", nil, nil)
    local textFS = frame:CreateFontString(nil, "OVERLAY")
    BubbleCensor.ApplyLabel(frame, textFS, { isCensored = true, text = "****" })

    local extra = BubbleCensor.ApplyLabel(frame, textFS, { text = "hello" })

    assert(extra == 0, "test_apply_label_hides_the_hint_for_a_plain_message: extra height " .. tostring(extra))
    assert(frame._censoredLabel.shown == false, "test_apply_label_hides_the_hint_for_a_plain_message: label hidden")
  end
end
