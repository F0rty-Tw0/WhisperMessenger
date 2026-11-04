local Card = require("tests.helpers.preview_reply_card")

local LOCK = "Competitive Content"

local function row(s)
  return s.card.replyHold.row
end

local function lockedCard()
  local s = Card.Build({ lock = LOCK })
  Card.ShowJaina(s)
  assert(row(s).isEnabled() == false, "the lock disables the row")
  return s
end

return function()
  local function test_lock_while_holding_stashes_and_disables()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    s.opts.lock = LOCK
    Card.ShowJaina(s)
    assert(#s.calls.saveDraft == 1, "one draft saved, got " .. #s.calls.saveDraft)
    assert(s.calls.saveDraft[1].meta.conversationKey == "wow::jaina" and s.calls.saveDraft[1].text == "brb", "the draft is Jaina's text")
    assert(Card.Text(s) == "", "the input is empty")
    assert(row(s).placeholder:GetText() == LOCK, "the placeholder shows the reason")
    assert(row(s).isEnabled() == false, "the row is disabled")
  end

  -- An applied update is the current truth, so the lock stash inside it never refreshes.
  local function test_lock_stash_after_an_ignored_update_does_not_refresh()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    Card.ShowThrall(s)
    s.opts.lock = LOCK
    Card.ShowJaina(s, Card.Jaina(600))
    assert(#s.calls.saveDraft == 1, "the text becomes a draft")
    assert(s.calls.refresh == 0, "no refresh from inside the update, got " .. s.calls.refresh)
  end

  local function test_lock_found_at_focus_disables()
    local s = Card.Build()
    Card.ShowJaina(s)
    s.opts.lock = LOCK
    Card.Focus(s)
    assert(row(s).isEnabled() == false, "the focus-time check disables the row")
    assert(Card.Input(s):HasFocus() == false, "the input drops focus")
  end

  local function test_lock_found_at_focus_while_stale_refreshes_once()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    Card.Blur(s)
    Card.ShowThrall(s)
    assert(Card.Sender(s) == "Jaina", "the typed text holds Jaina")
    s.opts.lock = "Mythic Lockdown"
    Card.Focus(s)
    assert(#s.calls.saveDraft == 1 and s.calls.saveDraft[1].text == "brb", "the text becomes a draft")
    assert(row(s).isEnabled() == false, "the row is disabled")
    assert(s.calls.refresh == 1, "the stale card refreshes once, got " .. s.calls.refresh)
  end

  local function test_disabled_click_with_lock_gone_enables_and_focuses()
    local s = lockedCard()
    s.opts.lock = nil
    Card.Fire(row(s).cover, "OnMouseDown")
    assert(row(s).isEnabled() == true, "the row enables")
    assert(Card.Input(s):HasFocus() == true, "the input takes focus")
  end

  local function test_disabled_click_while_locked_stays_disabled()
    local s = lockedCard()
    s.opts.lock = "In combat"
    Card.Fire(row(s).cover, "OnMouseDown")
    assert(row(s).isEnabled() == false, "the row stays disabled")
    assert(row(s).placeholder:GetText() == "In combat", "the reason is fresh")
    assert(Card.Input(s):HasFocus() == false, "no focus")
  end

  local function test_lock_lifts_on_next_update()
    local s = lockedCard()
    s.opts.lock = nil
    Card.ShowJaina(s, Card.Jaina(600))
    assert(row(s).isEnabled() == true, "the next update lifts the lock")
  end

  local function test_timer_paused_while_holding_and_rescheduled_at_hold_end()
    Card.WithTimers(function(timers)
      local s = Card.Build()
      Card.ShowJaina(s)
      assert(Card.LiveTimers(timers) == 1, "the show starts one timer")
      Card.Focus(s)
      assert(Card.LiveTimers(timers) == 0, "focus pauses the timer")
      s.card.setIncomingPreview("Jaina", "Still there?", "MAGE", Card.Jaina(600))
      assert(Card.LiveTimers(timers) == 0, "a changed update while holding keeps it paused, got " .. Card.LiveTimers(timers))
      Card.Blur(s)
      assert(Card.LiveTimers(timers) == 1, "hold end starts a new timer")
    end)
  end

  local function test_setting_turned_off_while_holding()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    s.opts.enabled = false
    Card.ShowJaina(s)
    assert(#s.calls.saveDraft == 1 and s.calls.saveDraft[1].text == "brb", "the text becomes a draft once")
    assert(s.card.replyHold.isRowShown() == false, "the row hides")
    assert(s.card.frame:IsShown() == true and Card.Sender(s) == "Jaina", "the card keeps Jaina")
    assert(s.calls.refresh == 0, "no refresh, got " .. s.calls.refresh)
  end

  -- The setting is read before the holding-ignore rule, so another chat's update applies.
  local function test_setting_off_while_holding_applies_another_chat()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    s.opts.enabled = false
    Card.ShowThrall(s)
    assert(#s.calls.saveDraft == 1 and s.calls.saveDraft[1].meta.conversationKey == "wow::jaina", "Jaina's text becomes her draft")
    assert(Card.Sender(s) == "Thrall", "the update applies, got " .. tostring(Card.Sender(s)))
    assert(s.card.replyHold.isRowShown() == false, "the row hides")
  end

  local function test_setting_off_while_locked_resets_enabled_state()
    local s = lockedCard()
    s.opts.enabled = false
    Card.ShowJaina(s)
    assert(row(s).isEnabled() == true, "hiding the row resets its enabled state")
    s.opts.enabled = true
    s.opts.lock = nil
    Card.ShowJaina(s)
    assert(s.card.replyHold.isRowShown() == true, "the row is back")
    assert(row(s).isEnabled() == true, "the row is enabled")
  end

  local function test_external_preview_ignored_while_holding_then_refresh()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    s.card.setExternalPreview(Card.External())
    assert(Card.Sender(s) == "Jaina", "the held card keeps Jaina")
    Card.TypeText(s, "")
    Card.Blur(s)
    assert(s.calls.refresh == 1, "hold end refreshes once, got " .. s.calls.refresh)
  end

  test_lock_while_holding_stashes_and_disables()
  test_lock_stash_after_an_ignored_update_does_not_refresh()
  test_lock_found_at_focus_disables()
  test_lock_found_at_focus_while_stale_refreshes_once()
  test_disabled_click_with_lock_gone_enables_and_focuses()
  test_disabled_click_while_locked_stays_disabled()
  test_lock_lifts_on_next_update()
  test_timer_paused_while_holding_and_rescheduled_at_hold_end()
  test_setting_turned_off_while_holding()
  test_setting_off_while_holding_applies_another_chat()
  test_setting_off_while_locked_resets_enabled_state()
  test_external_preview_ignored_while_holding_then_refresh()
end
