local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")

return function()
  -- test_typing_replaces_availability_label
  do
    local line1, line2, color = StatusLine.Build({ displayName = "Arthas", isTyping = true, className = "Mage" }, { status = "CanWhisper" })
    assert(string.find(line2, "typing", 1, true) == 1, "typing label leads line2: " .. line2)
    assert(not string.find(line2, "Online", 1, true), "availability label hidden while typing: " .. line2)
    assert(not string.find(line1, "typing", 1, true), "typing label should not appear on line1: " .. line1)
    assert(string.find(line1, "Mage", 1, true), "class still shown on line1: " .. line1)
    assert(not string.find(line2, "Mage", 1, true), "class should not appear on line2: " .. line2)
    assert(color == "online", "typing dot is online, got " .. tostring(color))
  end

  -- test_peer_badge_not_in_status_line
  do
    local line1, line2 = StatusLine.Build({ displayName = "Arthas", peerHasAddon = true }, { status = "CanWhisper" })
    assert(not string.find(line1, "WhisperMessenger", 1, true), "no addon badge text on line1: " .. line1)
    assert(not string.find(line1, "WM", 1, true), "no 'WM' text on line1: " .. line1)
    assert(not string.find(line2, "WhisperMessenger", 1, true), "no addon badge text on line2: " .. line2)
    assert(not string.find(line2, "WM", 1, true), "no 'WM' text on line2: " .. line2)
  end
end
