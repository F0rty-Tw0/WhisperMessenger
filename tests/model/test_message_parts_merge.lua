local MessageParts = require("WhisperMessenger.Model.MessageParts")

-- Merging the stored parts of one long whisper into a single message.

local function part(text, partIndex, join, extra)
  local message = { kind = "user", direction = "in", wireId = "abc1", text = text }
  if partIndex ~= nil then
    message.partIndex = partIndex
    message.partCount = 3
    message.join = join
  end
  for key, value in pairs(extra or {}) do
    message[key] = value
  end
  return message
end

local function conversation(messages, unreadCount)
  return { messages = messages, unreadCount = unreadCount or #messages }
end

local function first()
  return part("one")
end
local function second()
  return part("two", 2, " ")
end
local function third()
  return part("three", 3, "")
end

return function()
  -- test_merge_in_order_leaves_one_message_with_the_full_text
  do
    local c = conversation({ first(), second(), third() })
    assert(MessageParts.Merge(c, "abc1", "in") == true, "merged")
    assert(#c.messages == 1, "one message left, got " .. #c.messages)
    assert(c.messages[1].text == "one twothree", "joined text: " .. c.messages[1].text)
    assert(c.messages[1].parts == nil, "complete: parts dropped")
  end

  -- test_merge_out_of_order_keeps_the_earliest_as_host
  do
    local host = third()
    local c = conversation({ host, first(), second() })
    MessageParts.Merge(c, "abc1", "in")
    assert(#c.messages == 1 and c.messages[1] == host, "earliest placed hosts")
    assert(host.text == "one twothree", "text in part order: " .. host.text)
  end

  -- test_merge_is_idempotent
  do
    local c = conversation({ first(), second(), third() })
    MessageParts.Merge(c, "abc1", "in")
    assert(MessageParts.Merge(c, "abc1", "in") == false, "nothing left to merge")
    assert(#c.messages == 1 and c.messages[1].text == "one twothree", "unchanged")
  end

  -- test_gap_fills_when_the_late_part_arrives
  do
    local c = conversation({ first(), third() })
    MessageParts.Merge(c, "abc1", "in")
    local host = c.messages[1]
    assert(#c.messages == 1 and host.text == "onethree", "gap skipped: " .. host.text)
    assert(host.parts ~= nil, "incomplete: parts kept")
    table.insert(c.messages, second())
    MessageParts.Merge(c, "abc1", "in")
    assert(#c.messages == 1 and host.text == "one twothree", "gap filled: " .. host.text)
    assert(host.parts == nil, "complete now")
  end

  -- test_unread_drops_by_one_per_absorbed_incoming_part
  do
    local c = conversation({ first(), second(), third() }, 3)
    MessageParts.Merge(c, "abc1", "in")
    assert(c.unreadCount == 1, "3 parts = 1 unread, got " .. c.unreadCount)
  end

  -- test_unread_never_goes_below_zero
  do
    local c = conversation({ first(), second(), third() }, 0)
    MessageParts.Merge(c, "abc1", "in")
    assert(c.unreadCount == 0, "floor 0, got " .. c.unreadCount)
  end

  -- test_reply_and_reaction_on_a_later_part_move_to_the_host
  do
    local replyTo = { wireId = "x" }
    local reaction = { key = "heart" }
    local c = conversation({ first(), second(), part("three", 3, "", { replyTo = replyTo, reaction = reaction }) })
    MessageParts.Merge(c, "abc1", "in")
    assert(c.messages[1].replyTo == replyTo, "replyTo carried")
    assert(c.messages[1].reaction == reaction, "reaction carried")
  end

  -- test_previews_show_the_merged_text
  do
    local c = conversation({ first(), second(), third() })
    c.lastPreview = "three"
    c.lastIncomingPreview = "three"
    MessageParts.Merge(c, "abc1", "in")
    assert(c.lastPreview == "one twothree", "lastPreview: " .. tostring(c.lastPreview))
    assert(c.lastIncomingPreview == "one twothree", "lastIncomingPreview: " .. tostring(c.lastIncomingPreview))
  end

  -- test_messages_in_between_stay_and_keep_their_preview
  do
    local other = { kind = "user", direction = "out", text = "later reply" }
    local c = conversation({ first(), second(), third(), other })
    c.lastPreview = "later reply"
    MessageParts.Merge(c, "abc1", "in")
    assert(#c.messages == 2 and c.messages[2] == other, "other messages kept")
    assert(c.lastPreview == "later reply", "preview still the newest message")
    assert(c.lastIncomingPreview == "one twothree", "incoming preview merged")
  end

  -- test_other_direction_with_the_same_wire_id_is_not_merged
  do
    local mine = part("mine")
    mine.direction = "out"
    local c = conversation({ first(), mine, second() })
    MessageParts.Merge(c, "abc1", "in")
    assert(#c.messages == 2 and c.messages[2] == mine, "outgoing message untouched")
    assert(c.messages[1].text == "one two", "incoming parts merged: " .. c.messages[1].text)
  end
end
