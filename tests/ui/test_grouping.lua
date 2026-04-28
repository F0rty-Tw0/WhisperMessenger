local Grouping = require("WhisperMessenger.UI.ChatBubble.Grouping")

local function out(senderName, sentAt, playerName)
  return {
    direction = "out",
    kind = "user",
    senderName = senderName,
    sentAt = sentAt,
    playerName = playerName or "Bob",
  }
end

local function inMsg(playerName, sentAt)
  return {
    direction = "in",
    kind = "user",
    sentAt = sentAt,
    playerName = playerName,
  }
end

return function()
  -- Two outgoing messages from the same character within 120s should group.
  do
    local prev = out("CharA", 100)
    local current = out("CharA", 150)
    assert(Grouping.ShouldGroup(prev, current) == true, "same-character consecutive outgoing within 120s must group")
  end

  -- Two outgoing messages from DIFFERENT characters must NOT group, even
  -- inside the 120s window — this is the alt-switch regression.
  do
    local prev = out("CharA", 100)
    local current = out("CharB", 150)
    assert(Grouping.ShouldGroup(prev, current) == false, "different-character outgoing must break grouping")
  end

  -- nil senderName on legacy messages is treated as "" — two legacy outgoing
  -- messages still group (both have no stamped sender).
  do
    local prev = out(nil, 100)
    local current = out(nil, 150)
    assert(Grouping.ShouldGroup(prev, current) == true, "two legacy nil-sender outgoing messages must still group")
  end

  -- Legacy (nil) followed by a stamped outgoing message must break the group
  -- so the stamped one renders its own label.
  do
    local prev = out(nil, 100)
    local current = out("CharB", 150)
    assert(Grouping.ShouldGroup(prev, current) == false, "legacy outgoing followed by stamped sender must break grouping")
  end

  -- Direction change still breaks regardless.
  do
    local prev = out("CharA", 100)
    local current = inMsg("Bob", 150)
    assert(Grouping.ShouldGroup(prev, current) == false, "direction change always breaks grouping")
  end

  -- Time gap > 120s breaks even when senderName matches.
  do
    local prev = out("CharA", 100)
    local current = out("CharA", 250)
    assert(Grouping.ShouldGroup(prev, current) == false, "time gap > 120s breaks grouping")
  end

  -- Incoming-incoming grouping is unaffected by the new senderName check
  -- because incoming messages legitimately have no senderName.
  do
    local prev = inMsg("Bob", 100)
    local current = inMsg("Bob", 150)
    assert(Grouping.ShouldGroup(prev, current) == true, "incoming messages from same player must still group")
  end
end
