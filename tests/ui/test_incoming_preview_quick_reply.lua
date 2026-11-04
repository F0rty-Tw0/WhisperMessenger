local LinkHooks = require("WhisperMessenger.UI.Composer.LinkHooks")
local Card = require("tests.helpers.preview_reply_card")

return function()
  local function test_row_shows_only_with_setting_meta_and_own_preview()
    local s = Card.Build()
    s.card.setIncomingPreview("Jaina", "Need help?", "MAGE")
    assert(s.card.replyHold.isRowShown() == false, "no meta, no row")

    s.opts.enabled = false
    Card.ShowJaina(s)
    assert(s.card.replyHold.isRowShown() == false, "setting off, no row")

    s.opts.enabled = true
    Card.ShowJaina(s, Card.Jaina(501))
    assert(s.card.replyHold.isRowShown() == true, "setting, meta and own preview show the row")

    s.card.setExternalPreview(Card.External())
    assert(s.card.replyHold.isRowShown() == false, "an external entry hides the row")
  end

  local function test_setting_off_creates_no_input()
    local saved = LinkHooks.RegisterInput
    local registered = 0
    rawset(LinkHooks, "RegisterInput", function()
      registered = registered + 1
    end)
    local ok, err = pcall(function()
      local s = Card.Build({ enabled = false })
      Card.ShowJaina(s)
      assert(s.card.replyHold.row == nil, "no row is built with the setting off")
    end)
    rawset(LinkHooks, "RegisterInput", saved)
    assert(ok, err)
    assert(registered == 0, "no input registers with LinkHooks, got " .. registered)
  end

  local function test_other_conversation_ignored_while_holding_then_one_refresh_on_blur()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.ShowThrall(s)
    assert(Card.Sender(s) == "Jaina", "the held card keeps Jaina, got " .. tostring(Card.Sender(s)))
    Card.Blur(s)
    assert(s.calls.refresh == 1, "hold end refreshes once, got " .. s.calls.refresh)
  end

  local function test_same_conversation_update_replaces_held_meta()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "hi")
    Card.ShowJaina(s, Card.Jaina(600))
    Card.Enter(s)
    assert(#s.calls.submit == 1, "one submit")
    assert(s.calls.submit[1].meta.sentAt == 600, "submit uses the newer meta")
  end

  local function test_refresh_inside_submit_writes_no_draft_and_refreshes_once_after()
    local s = Card.Build()
    s.opts.submit = function()
      s.card.setIncomingPreview(nil)
      Card.ShowThrall(s)
      return true
    end
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "hi")
    Card.Enter(s)
    assert(#s.calls.saveDraft == 0, "no draft written during submit")
    assert(Card.Text(s) == "", "the input is empty after a sent reply")
    assert(s.card.frame:IsShown() == false, "the card hides after a sent reply")
    assert(s.calls.refresh == 1, "one refresh after submit, got " .. s.calls.refresh)
  end

  local function test_submit_false_keeps_text_and_stale_until_hold_end()
    local s = Card.Build()
    s.opts.submit = function()
      Card.ShowThrall(s)
      return false
    end
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "hi")
    Card.Enter(s)
    assert(Card.Text(s) == "hi", "a refused submit keeps the text")
    assert(s.calls.refresh == 0, "no refresh while still holding")
    Card.TypeText(s, "")
    Card.Blur(s)
    assert(s.calls.refresh == 1, "hold end refreshes the stale card, got " .. s.calls.refresh)
  end

  local function test_cleared_while_holding_saves_draft_without_refresh()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    s.card.setIncomingPreview(nil)
    assert(#s.calls.saveDraft == 1, "one draft saved")
    assert(s.calls.saveDraft[1].meta.conversationKey == "wow::jaina" and s.calls.saveDraft[1].text == "brb", "the draft is Jaina's text")
    assert(s.card.frame:IsShown() == false, "the card hides")
    assert(s.calls.refresh == 0, "no refresh from a clear")
  end

  local function test_dismiss_while_holding_acks_through_held_meta()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    Card.Fire(s.card.dismissButton, "OnClick")
    assert(#s.calls.saveDraft == 1 and s.calls.saveDraft[1].text == "brb", "the draft is saved")
    assert(#s.calls.dismissThrough == 1 and s.calls.dismissThrough[1].conversationKey == "wow::jaina", "acks through Jaina")
    assert(s.calls.dismissed == 0, "today's dismiss is skipped")
  end

  local function test_idle_dismiss_is_todays_dismiss()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Fire(s.card.dismissButton, "OnClick")
    assert(s.calls.dismissed == 1, "today's dismiss runs")
    assert(#s.calls.dismissThrough == 0, "no ack-through when idle")
  end

  local function test_body_click_while_holding_opens_held_meta()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    Card.Fire(s.card.frame, "OnMouseUp", "LeftButton")
    assert(#s.calls.open == 1 and s.calls.open[1].meta.conversationKey == "wow::jaina", "opens the held chat")
    assert(s.calls.open[1].text == "brb", "passes the typed text")
    assert(s.calls.opened == 0, "today's open is skipped")
    assert(Card.Text(s) == "", "the input empties after the open")
    assert(s.calls.refresh == 0, "no refresh from an open")
  end

  local function test_refused_body_click_keeps_text()
    local s = Card.Build({
      open = function()
        return false
      end,
    })
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    Card.Fire(s.card.frame, "OnMouseUp", "LeftButton")
    assert(Card.Text(s) == "brb", "a refused open keeps the text")
    assert(#s.calls.saveDraft == 0, "no draft from a refused open")
  end

  local function test_body_click_open_reentry_writes_no_second_draft()
    local s = Card.Build()
    s.opts.open = function()
      s.card.setIncomingPreview(nil)
      return true
    end
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    Card.Fire(s.card.frame, "OnMouseUp", "LeftButton")
    assert(#s.calls.saveDraft == 0, "the open's own draft write is the only one, got " .. #s.calls.saveDraft)
    assert(s.card.frame:IsShown() == false, "the re-entrant refresh hid the card")
    assert(Card.Text(s) == "", "the input is empty")
  end

  local function test_submit_error_resets_submitting()
    local s = Card.Build({
      submit = function()
        error("send exploded", 0)
      end,
    })
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "hi")
    local ok, err = pcall(Card.Enter, s)
    assert(ok == false and tostring(err):find("send exploded", 1, true), "the error surfaces, got " .. tostring(err))
    Card.TypeText(s, "")
    Card.Blur(s)
    Card.ShowThrall(s)
    assert(Card.Sender(s) == "Thrall", "the card is not frozen, got " .. tostring(Card.Sender(s)))
  end

  test_row_shows_only_with_setting_meta_and_own_preview()
  test_setting_off_creates_no_input()
  test_other_conversation_ignored_while_holding_then_one_refresh_on_blur()
  test_same_conversation_update_replaces_held_meta()
  test_refresh_inside_submit_writes_no_draft_and_refreshes_once_after()
  test_submit_false_keeps_text_and_stale_until_hold_end()
  test_cleared_while_holding_saves_draft_without_refresh()
  test_dismiss_while_holding_acks_through_held_meta()
  test_idle_dismiss_is_todays_dismiss()
  test_body_click_while_holding_opens_held_meta()
  test_refused_body_click_keeps_text()
  test_body_click_open_reentry_writes_no_second_draft()
  test_submit_error_resets_submitting()
end
