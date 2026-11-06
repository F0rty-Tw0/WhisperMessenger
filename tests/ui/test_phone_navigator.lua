local PhoneNavigator = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneNavigator")

local function build()
  local case = { shown = true, covered = false, cleared = 0, focused = 0, snaps = {}, animations = {} }
  case.slide = {
    snapTo = function(target)
      case.snaps[#case.snaps + 1] = target
    end,
    animateTo = function(target, done)
      case.animations[#case.animations + 1] = target
      case.done = done
    end,
    finishNow = function()
      local done = case.done
      case.done = nil
      if done then
        done()
      end
    end,
  }
  case.nav = PhoneNavigator.Create({
    slide = case.slide,
    isAnimatable = function()
      return case.shown and not case.covered
    end,
    onChatView = function(inChat)
      case.chatView = inChat
    end,
    getSelectedKey = function()
      return case.selected
    end,
    clearSelection = function()
      case.cleared = case.cleared + 1
      case.selected = nil
      case.nav.syncSelection(nil)
    end,
    focusChat = function()
      case.focused = case.focused + 1
    end,
  })
  return case
end

local function open(case, key)
  case.selected = key
  case.nav.syncSelection(key)
  case.slide.finishNow()
end

return function()
  -- test_selecting_a_chat_slides_to_it
  do
    local case = build()
    case.selected = "a"
    case.nav.syncSelection("a")
    assert(case.animations[1] == 1, "slides to the chat")
    assert(case.chatView == true, "the chrome switches at once")
    assert(not case.nav.isListView(), "chat view")
  end

  -- test_arriving_at_a_chat_offers_it_focus
  do
    local case = build()
    open(case, "a")
    assert(case.focused == 1, "focus follows the slide")
  end

  -- test_selecting_while_hidden_snaps
  do
    local case = build()
    case.shown = false
    case.nav.syncSelection("a")
    assert(case.snaps[#case.snaps] == 1 and #case.animations == 0, "a hidden window does not animate")
  end

  -- test_refresh_of_the_open_chat_does_not_restart_the_slide
  do
    local case = build()
    open(case, "a")
    case.nav.syncSelection("a")
    assert(#case.animations == 1, "already there")
  end

  -- test_back_keeps_the_chat_until_the_slide_ends
  do
    local case = build()
    open(case, "a")
    assert(case.nav.back() == true, "back is handled")
    assert(case.animations[2] == 0, "slides to the list")
    assert(case.cleared == 0, "the chat stays filled during the slide")
    assert(case.chatView == false, "list chrome returns at once")
    case.slide.finishNow()
    assert(case.cleared == 1, "then the selection clears, so new whispers count as unread")
  end

  -- test_refresh_during_back_does_not_bounce_to_the_chat
  do
    local case = build()
    open(case, "a")
    case.nav.back()
    case.nav.syncSelection("a")
    assert(#case.animations == 2, "a whisper landing mid-slide does not reverse it")
    assert(case.nav.isListView(), "still leaving")
  end

  -- test_picking_another_chat_during_back_goes_to_it
  do
    local case = build()
    open(case, "a")
    case.nav.back()
    case.selected = "b"
    case.nav.syncSelection("b")
    assert(case.animations[3] == 1, "turns around for the new chat")
    case.slide.finishNow()
    assert(case.cleared == 0, "the new chat is not cleared")
  end

  -- test_back_on_the_list_is_not_handled
  do
    local case = build()
    assert(case.nav.back() == false, "nothing to go back to")
    assert(case.cleared == 0, "no selection change")
  end

  -- test_chat_removed_elsewhere_returns_to_the_list
  do
    local case = build()
    open(case, "a")
    case.selected = nil
    case.nav.syncSelection(nil)
    assert(case.animations[2] == 0, "back to the list")
  end

  -- test_show_list_snaps_with_no_slide
  do
    local case = build()
    open(case, "a")
    case.nav.showList()
    assert(case.snaps[#case.snaps] == 0, "opens straight on the list")
    assert(#case.animations == 1, "no slide")
    assert(case.nav.isListView() and case.chatView == false, "list view and chrome")
  end
end
