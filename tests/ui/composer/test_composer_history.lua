local FakeUI = require("tests.helpers.fake_ui")
local ComposerHistory = require("WhisperMessenger.UI.Composer.ComposerHistory")

local FITS = function()
  return true
end

local function build(entries, options)
  options = options or {}
  local input = FakeUI.NewFactory().CreateFrame("EditBox", nil, nil)
  input:SetText("")
  if options.previous then
    input:SetScript("OnKeyDown", options.previous)
  end
  local got = { asked = 0, refreshed = 0 }
  local parts = {
    getSentHistory = function(fits)
      got.asked = got.asked + 1
      got.fits = fits
      return entries or { "e1", "e2", "e3" }
    end,
    fits = FITS,
  }
  if options.noHistory then
    parts.getSentHistory = nil
  end
  local history
  parts.refresh = function()
    got.refreshed = got.refreshed + 1
    got.putting = history.putting()
    if options.echo then
      history.textChanged(input:GetText())
    end
  end
  history = ComposerHistory.Create(input, parts)
  local function press(key)
    input.scripts.OnKeyDown(input, key)
  end
  return input, history, press, got
end

return function()
  -- test_up_on_empty_box_puts_the_newest_line
  do
    local input, _, press = build()
    press("UP")
    assert(input:GetText() == "e1", "Up on an empty box puts the newest line")
  end

  -- test_recall_puts_the_cursor_at_the_end
  do
    local input, _, press = build()
    input:SetCursorPosition(0)
    press("UP")
    assert(input:GetCursorPosition() == 2, "cursor at the end of the recalled line")
  end

  -- test_recall_runs_refresh_while_putting
  do
    local _, history, press, got = build()
    press("UP")
    assert(got.refreshed == 1 and got.putting == true, "refresh runs once while putting")
    assert(history.putting() == false, "putting ends after the recall")
  end

  -- test_recall_asks_with_the_fits_predicate
  do
    local _, _, press, got = build()
    press("UP")
    assert(got.fits == FITS, "the list is built with the open chat's fit check")
  end

  -- test_empty_history_ignores_up
  do
    local input, _, press, got = build({})
    press("UP")
    assert(input:GetText() == "" and got.refreshed == 0, "an empty history leaves the box alone")
  end

  -- test_up_with_text_keeps_the_default
  do
    local input, _, press, got = build()
    input:SetText("typed")
    press("UP")
    assert(input:GetText() == "typed" and got.asked == 0, "Up in a box with text keeps the default")
  end

  -- test_down_when_idle_keeps_the_default
  do
    local input, _, press = build()
    press("DOWN")
    assert(input:GetText() == "", "Down on an empty box does nothing")
    input:SetText("typed")
    press("DOWN")
    assert(input:GetText() == "typed", "Down in a box with text does nothing")
  end

  -- test_up_steps_back_and_stays_at_the_oldest
  do
    local input, _, press, got = build()
    for _ = 1, 4 do
      press("UP")
    end
    assert(input:GetText() == "e3" and got.refreshed == 3, "Up stops at the oldest line")
  end

  -- test_list_is_built_once_per_recall
  do
    local _, _, press, got = build()
    press("UP")
    press("UP")
    press("DOWN")
    assert(got.asked == 1, "one list per recall")
  end

  -- test_down_steps_forward
  do
    local input, _, press = build()
    press("UP")
    press("UP")
    press("DOWN")
    assert(input:GetText() == "e1", "Down steps to the newer line")
  end

  -- test_down_at_newest_clears_and_ends
  do
    local input, _, press, got = build()
    press("UP")
    press("DOWN")
    assert(input:GetText() == "", "Down at the newest line clears the box")
    press("DOWN")
    assert(input:GetText() == "", "the recall ended")
    press("UP")
    assert(input:GetText() == "e1" and got.asked == 2, "the next Up starts a fresh recall")
  end

  -- test_up_after_an_unseen_edit_ends_the_recall
  do
    local input, _, press = build()
    press("UP")
    input:SetText("e1x")
    press("UP")
    assert(input:GetText() == "e1x", "an edited line keeps the default on Up")
  end

  -- test_down_after_an_unseen_edit_ends_the_recall
  do
    local input, _, press = build()
    press("UP")
    press("UP")
    input:SetText("e2x")
    press("DOWN")
    assert(input:GetText() == "e2x", "an edited line keeps the default on Down")
  end

  -- test_text_change_ends_the_recall
  do
    local input, history, press = build()
    press("UP")
    input:SetText("e1 more")
    history.textChanged("e1 more")
    input:SetText("e1")
    press("UP")
    assert(input:GetText() == "e1", "a text change ends the recall")
  end

  -- test_change_while_putting_is_ignored
  do
    local input, _, press = build(nil, { echo = true })
    press("UP")
    press("UP")
    assert(input:GetText() == "e2", "the put's own text change keeps the recall")
  end

  -- test_stop_ends_the_recall
  do
    local input, history, press = build()
    press("UP")
    history.stop()
    press("UP")
    assert(input:GetText() == "e1", "stop ends the recall")
  end

  -- test_left_right_keep_the_recall
  do
    local input, _, press = build()
    press("UP")
    press("LEFT")
    press("RIGHT")
    assert(input:GetText() == "e1", "Left/Right leave the text")
    press("UP")
    assert(input:GetText() == "e2", "Left/Right keep the recall")
  end

  -- test_other_keys_and_unhandled_presses_reach_the_old_handler
  do
    local calls = {}
    local input, _, press = build(nil, {
      previous = function(self, key)
        calls[#calls + 1] = { self = self, key = key }
      end,
    })
    input:SetText("typed")
    press("LEFT")
    press("UP")
    assert(#calls == 2, "other keys and unhandled Up reach the old handler")
    assert(calls[1].self == input and calls[1].key == "LEFT", "LEFT passed on")
    assert(calls[2].self == input and calls[2].key == "UP", "unhandled UP passed on")
    input:SetText("")
    press("UP")
    assert(#calls == 2, "a handled Up does not reach the old handler")
  end

  -- test_missing_get_sent_history_ignores_up
  do
    local input, _, press = build(nil, { noHistory = true })
    press("UP")
    assert(input:GetText() == "", "no history source leaves the box alone")
  end
end
