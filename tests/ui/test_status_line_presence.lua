local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")

return function()
  -- test_typing_replaces_availability_label
  do
    local text, color = StatusLine.Build({ displayName = "Arthas", isTyping = true, className = "Mage" }, { status = "CanWhisper" })
    assert(string.find(text, "typing", 1, true) == 1, "typing label leads the status line: " .. text)
    assert(not string.find(text, "Online", 1, true), "availability label hidden while typing: " .. text)
    assert(string.find(text, "Mage", 1, true), "class still shown: " .. text)
    assert(color == "online", "typing dot is online, got " .. tostring(color))
  end

  -- test_peer_badge_appended
  do
    local text = StatusLine.Build({ displayName = "Arthas", peerHasAddon = true }, { status = "CanWhisper" })
    assert(string.find(text, "Uses WhisperMessenger", 1, true), "peer badge shown: " .. text)
    local plain = StatusLine.Build({ displayName = "Arthas" }, { status = "CanWhisper" })
    assert(not string.find(plain, "WhisperMessenger", 1, true), "no badge without peer: " .. plain)
  end
end
