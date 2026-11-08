local Card = require("tests.helpers.preview_reply_card")

-- openShownPreview is the button-click path: it opens the whisper card on
-- screen and reports whether the chat opened, so the caller can fall back to
-- the plain toggle when it did not.

local function refuseOpen()
  return false
end

return function()
  local function test_refused_open_of_a_held_draft_reports_not_opened()
    local s = Card.Build({ open = refuseOpen })
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "draft")
    assert(s.card.openShownPreview() == false, "a refused open must let the caller toggle")
    assert(#s.calls.open == 1, "the open was tried once, got " .. #s.calls.open)
  end

  local function test_held_draft_opens_the_held_chat_not_the_latest_whisper()
    local s = Card.Build()
    Card.ShowJaina(s)
    Card.Focus(s)
    Card.TypeText(s, "brb")
    Card.Blur(s)
    Card.ShowThrall(s)
    assert(s.card.openShownPreview() == true, "the held chat opens")
    assert(#s.calls.open == 1 and s.calls.open[1].meta.conversationKey == "wow::jaina", "Jaina's chat opens")
  end

  local function test_another_addons_card_is_not_opened()
    local s = Card.Build()
    s.card.setExternalPreview(Card.External())
    assert(s.card.openShownPreview() == false, "an external card is not a whisper")
    assert(s.calls.opened == 0 and #s.calls.open == 0, "nothing opens")
  end

  local function test_card_under_a_hidden_parent_is_not_opened()
    local s = Card.Build()
    Card.ShowJaina(s)
    s.card.frame:GetParent():Hide()
    assert(s.card.openShownPreview() == false, "a card nobody sees does not open")
    assert(s.calls.opened == 0, "nothing opens")
  end

  test_refused_open_of_a_held_draft_reports_not_opened()
  test_held_draft_opens_the_held_chat_not_the_latest_whisper()
  test_another_addons_card_is_not_opened()
  test_card_under_a_hidden_parent_is_not_opened()
end
