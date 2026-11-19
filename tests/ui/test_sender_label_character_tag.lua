local FakeUI = require("tests.helpers.fake_ui")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

-- In a Battle.net chat, a line the friend sent from a character reads
-- "Friend - via Arthas": the friend's name, then the character tag.
local BN_CHAT = { conversationChannel = "BN", conversationDisplayName = "Friend#1234" }

local function shownText(fs)
  if fs == nil or (fs.IsShown and not fs:IsShown()) then
    return nil
  end
  return fs:GetText()
end

return function()
  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  local function render(message, options)
    return SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0, options).frame
  end

  local function characterLine(name)
    return { direction = "in", kind = "user", text = "hi", sentAt = 1000, channel = "WOW", playerName = name }
  end

  -- test_character_line_in_bn_chat_reads_friend_via_character
  do
    local frame = render(characterLine("Arthas"), BN_CHAT)
    local name, tag = shownText(frame._wmSenderNameFS), shownText(frame._wmSenderTagFS)
    assert(name == "Friend", "the name shows the friend, got " .. tostring(name))
    assert(tag == "- via Arthas", "the tag names the character, got " .. tostring(tag))
    assert(name .. " " .. tag == "Friend - via Arthas", "the line reads 'Friend - via Arthas'")
    assert(frame._wmSenderTagFS.point[2] == frame._wmSenderNameFS, "the tag sits right of the name")
  end

  -- test_cross_realm_character_tag_shows_the_stored_name_realm
  do
    local frame = render(characterLine("Arthas-Stormrage"), BN_CHAT)
    local tag = shownText(frame._wmSenderTagFS)
    assert(tag == "- via Arthas-Stormrage", "cross-realm tag keeps Name-Realm, got " .. tostring(tag))
  end

  -- test_battle_net_line_in_bn_chat_has_no_character_tag
  do
    local bnLine = { direction = "in", kind = "user", text = "hi", sentAt = 1000, channel = "BN", playerName = "Friend#1234" }
    local frame = render(bnLine, BN_CHAT)
    assert(shownText(frame._wmSenderNameFS) == "Friend", "a Battle.net line still shows the friend")
    assert(shownText(frame._wmSenderTagFS) == nil, "a Battle.net line has no tag")
  end

  -- test_character_chat_has_no_character_tag
  do
    local frame = render(characterLine("Arthas"), { conversationChannel = "WOW", conversationDisplayName = "Arthas" })
    assert(shownText(frame._wmSenderNameFS) == "Arthas", "a character chat shows the character")
    assert(shownText(frame._wmSenderTagFS) == nil, "a character chat has no tag")
  end

  -- test_sent_line_to_character_has_no_tag
  do
    local sent = { direction = "out", kind = "user", text = "hi", sentAt = 1000, channel = "WOW", playerName = "Arthas" }
    local frame = render(sent, BN_CHAT)
    assert(shownText(frame._wmSenderTagFS) == nil, "a sent line has no tag")
  end

  -- test_character_line_without_chat_name_keeps_the_character_name
  do
    local frame = render(characterLine("Arthas"), { conversationChannel = "BN" })
    assert(shownText(frame._wmSenderNameFS) == "Arthas", "no chat name: the name falls back to the line's")
    assert(shownText(frame._wmSenderTagFS) == "- via Arthas", "the tag still shows")
  end

  -- test_other_chat_lines_keep_their_own_sender_name
  do
    local line = { direction = "in", kind = "user", text = "hi", sentAt = 1000, playerName = "Jaina" }
    local frame = render(line, { conversationChannel = "PARTY", conversationDisplayName = "Party" })
    assert(shownText(frame._wmSenderNameFS) == "Jaina", "a party line shows its sender, got " .. tostring(shownText(frame._wmSenderNameFS)))
    assert(shownText(frame._wmSenderTagFS) == nil, "a party line has no character tag")
  end

  -- test_time_sits_right_of_the_character_tag
  do
    local frame = render(characterLine("Arthas"), BN_CHAT)
    assert(frame._wmSenderTimeFS.point[2] == frame._wmSenderTagFS, "the time follows the tag, not the name")
  end

  -- test_character_line_with_empty_name_has_no_tag
  do
    local frame = render(characterLine(""), BN_CHAT)
    assert(shownText(frame._wmSenderTagFS) == nil, "an empty character name draws no tag")
  end

  -- test_empty_chat_name_keeps_the_character_name
  do
    local frame = render(characterLine("Arthas"), { conversationChannel = "BN", conversationDisplayName = "" })
    assert(shownText(frame._wmSenderNameFS) == "Arthas", "an empty chat name falls back to the line's name")
  end
end
