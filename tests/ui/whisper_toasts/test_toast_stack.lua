local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ToastStack = require("WhisperMessenger.UI.WhisperToasts.ToastStack")

-- Pop-up cards for new whispers: one card per conversation, at most three.

local function entry(key, sender, text)
  return { conversationKey = key, senderName = sender, messageText = text, classTag = "MAGE" }
end

-- The card frame that shows `text`, or nil when no shown card does.
local function shownCard(parent, text)
  local label = FindUI.text(parent, text)
  local card = label and label.parent
  if card and card:IsShown() then
    return card
  end
  return nil
end

local function shownCount(parent)
  local count = 0
  for _, child in ipairs(parent.children) do
    if child.frameType == "Button" and child:IsShown() then
      count = count + 1
    end
  end
  return count
end

local function build(onOpen)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local stack = ToastStack.Create(factory, parent, { onOpen = onOpen or function() end })
  return stack, parent
end

return function()
  -- test_show_puts_up_a_card_with_sender_and_text
  do
    local stack, parent = build()
    stack.show(entry("k1", "Jaina", "hello there"), "TOPRIGHT")
    local card = shownCard(parent, "hello there")
    assert(card ~= nil, "a card shows the message text")
    assert(FindUI.text(card, "Jaina") ~= nil, "the card names the sender")
  end

  -- test_same_conversation_updates_its_card_in_place
  do
    local stack, parent = build()
    stack.show(entry("k1", "Jaina", "first"), "TOPRIGHT")
    stack.show(entry("k1", "Jaina", "second"), "TOPRIGHT")
    assert(shownCount(parent) == 1, "one card per conversation, got " .. shownCount(parent))
    assert(shownCard(parent, "second") ~= nil, "the card shows the newest line")
  end

  -- test_fourth_conversation_replaces_the_oldest_card
  do
    local stack, parent = build()
    stack.show(entry("k1", "A", "from a"), "TOPRIGHT")
    stack.show(entry("k2", "B", "from b"), "TOPRIGHT")
    stack.show(entry("k3", "C", "from c"), "TOPRIGHT")
    stack.show(entry("k4", "D", "from d"), "TOPRIGHT")
    assert(shownCount(parent) == 3, "at most three cards, got " .. shownCount(parent))
    assert(shownCard(parent, "from a") == nil, "the oldest card is gone")
    assert(shownCard(parent, "from b") and shownCard(parent, "from c") and shownCard(parent, "from d"), "the newer three stay")
  end

  -- test_replacing_card_moves_the_new_chat_to_the_last_slot
  do
    local stack, parent = build()
    stack.show(entry("k1", "A", "from a"), "TOPRIGHT")
    stack.show(entry("k2", "B", "from b"), "TOPRIGHT")
    stack.show(entry("k3", "C", "from c"), "TOPRIGHT")
    stack.show(entry("k4", "D", "from d"), "TOPRIGHT")
    local b, c, d = shownCard(parent, "from b"), shownCard(parent, "from c"), shownCard(parent, "from d")
    assert(b.point[5] > c.point[5], "the older cards keep their order")
    assert(c.point[5] > d.point[5], "the newest chat takes the last slot, away from the corner")
  end

  -- test_an_updated_card_is_not_the_oldest
  do
    local stack, parent = build()
    stack.show(entry("k1", "A", "from a"), "TOPRIGHT")
    stack.show(entry("k2", "B", "from b"), "TOPRIGHT")
    stack.show(entry("k3", "C", "from c"), "TOPRIGHT")
    stack.show(entry("k1", "A", "a again"), "TOPRIGHT")
    stack.show(entry("k4", "D", "from d"), "TOPRIGHT")
    assert(shownCard(parent, "a again") ~= nil, "a card with a fresh line survives")
    assert(shownCard(parent, "from b") == nil, "the least recently updated card is replaced")
  end

  -- test_cards_anchor_to_the_chosen_corner
  do
    local stack, parent = build()
    stack.show(entry("k1", "A", "from a"), "BOTTOMLEFT")
    local card = shownCard(parent, "from a")
    assert(card.point[1] == "BOTTOMLEFT" and card.point[2] == parent and card.point[3] == "BOTTOMLEFT", "card anchors to the bottom-left corner")
    assert(card.point[4] > 0 and card.point[5] > 0, "bottom-left cards sit inside the screen")
  end

  -- test_second_card_stacks_away_from_the_corner
  do
    local stack, parent = build()
    stack.show(entry("k1", "A", "from a"), "TOPRIGHT")
    stack.show(entry("k2", "B", "from b"), "TOPRIGHT")
    local first, second = shownCard(parent, "from a"), shownCard(parent, "from b")
    assert(first.point[1] == "TOPRIGHT" and second.point[1] == "TOPRIGHT", "both cards anchor top-right")
    assert(second.point[5] < first.point[5], "the second card sits below the first")
  end

  -- test_clicking_a_card_opens_its_conversation_and_dismisses_it
  do
    local opened = {}
    local stack, parent = build(function(key)
      opened[#opened + 1] = key
    end)
    stack.show(entry("k1", "A", "from a"), "TOPRIGHT")
    stack.show(entry("k2", "B", "from b"), "TOPRIGHT")
    FindUI.click(shownCard(parent, "from b"))
    assert(opened[1] == "k2" and #opened == 1, "click opens that card's conversation")
    assert(shownCard(parent, "from b") == nil, "the clicked card is dismissed")
    assert(shownCard(parent, "from a") ~= nil, "other cards stay")
  end

  -- test_clear_dismisses_every_card
  do
    local stack, parent = build()
    stack.show(entry("k1", "A", "from a"), "TOPRIGHT")
    stack.show(entry("k2", "B", "from b"), "TOPRIGHT")
    stack.clear()
    assert(shownCount(parent) == 0, "no card stays after clear")
  end

  -- test_card_fades_after_its_timer_and_a_new_line_restarts_it
  do
    local timers = {}
    local savedTimer = _G.C_Timer
    _G.C_Timer = {
      After = function() end,
      NewTimer = function(seconds, callback)
        local timer = { seconds = seconds, callback = callback }
        function timer:Cancel()
          self.cancelled = true
        end
        timers[#timers + 1] = timer
        return timer
      end,
    }
    local stack, parent = build()
    stack.show(entry("k1", "A", "first"), "TOPRIGHT")
    assert(#timers == 1 and timers[1].seconds > 0, "showing a card starts its timer")
    stack.show(entry("k1", "A", "second"), "TOPRIGHT")
    assert(timers[1].cancelled == true and #timers == 2, "a new line restarts the timer")
    timers[2].callback()
    assert(shownCount(parent) == 0, "the card goes away when its timer runs out")
    _G.C_Timer = savedTimer
  end
end
