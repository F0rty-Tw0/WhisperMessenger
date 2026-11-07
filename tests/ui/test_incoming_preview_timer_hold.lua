local Card = require("tests.helpers.preview_reply_card")

-- The card's auto-dismiss timer waits while the reply box has keyboard focus
-- or the cursor is over the card, and runs again once both are gone.

local function hover(s, over)
  local frame = s.card.frame
  frame.mouseOver = over
  if over then
    Card.Fire(frame, "OnEnter")
  end
  local onUpdate = frame:GetScript("OnUpdate")
  if onUpdate then
    onUpdate(frame, 0.1)
  end
end

local function lastTimer(timers)
  return timers[#timers]
end

return function()
  local function test_timer_runs_again_after_blur_with_unsent_text()
    Card.WithTimers(function(timers)
      local s = Card.Build()
      Card.ShowJaina(s)
      Card.Focus(s)
      Card.TypeText(s, "brb")
      assert(Card.LiveTimers(timers) == 0, "focus holds the timer")
      Card.Blur(s)
      assert(Card.LiveTimers(timers) == 1, "blur starts the timer though text is left, got " .. Card.LiveTimers(timers))
      lastTimer(timers).callback()
      assert(s.card.frame:IsShown() == false, "the card closes when the timer expires")
      assert(#s.calls.saveDraft == 1 and s.calls.saveDraft[1].text == "brb", "the unsent text is kept as a draft")
    end)
  end

  local function test_hover_holds_the_timer_until_the_cursor_leaves()
    Card.WithTimers(function(timers)
      local s = Card.Build()
      Card.ShowJaina(s)
      assert(Card.LiveTimers(timers) == 1, "the show starts one timer")
      hover(s, true)
      assert(Card.LiveTimers(timers) == 0, "hover holds the timer")
      hover(s, true)
      assert(Card.LiveTimers(timers) == 0, "still over the card: still held")
      hover(s, false)
      assert(Card.LiveTimers(timers) == 1, "leaving starts the timer again, got " .. Card.LiveTimers(timers))
      lastTimer(timers).callback()
      assert(s.card.frame:IsShown() == false, "the card closes when the timer expires")
    end)
  end

  local function test_focus_and_hover_both_must_end()
    Card.WithTimers(function(timers)
      local s = Card.Build()
      Card.ShowJaina(s)
      hover(s, true)
      Card.Focus(s)
      Card.Blur(s)
      assert(Card.LiveTimers(timers) == 0, "the cursor still holds it")
      Card.Focus(s)
      hover(s, false)
      assert(Card.LiveTimers(timers) == 0, "the focus still holds it")
      Card.Blur(s)
      assert(Card.LiveTimers(timers) == 1, "both gone: one timer, got " .. Card.LiveTimers(timers))
    end)
  end

  local function test_a_hidden_card_drops_the_hover_hold()
    Card.WithTimers(function(timers)
      local s = Card.Build()
      Card.ShowJaina(s)
      hover(s, true)
      s.card.setIncomingPreview(nil)
      Card.ShowThrall(s)
      assert(Card.LiveTimers(timers) == 1, "the next card times out as usual, got " .. Card.LiveTimers(timers))
    end)
  end

  local function test_hover_on_an_external_preview_starts_no_timer()
    Card.WithTimers(function(timers)
      local s = Card.Build()
      s.card.setExternalPreview(Card.External())
      hover(s, true)
      hover(s, false)
      assert(Card.LiveTimers(timers) == 0, "an external preview never times out, got " .. Card.LiveTimers(timers))
    end)
  end

  test_timer_runs_again_after_blur_with_unsent_text()
  test_hover_holds_the_timer_until_the_cursor_leaves()
  test_focus_and_hover_both_must_end()
  test_a_hidden_card_drops_the_hover_hold()
  test_hover_on_an_external_preview_starts_no_timer()
end
