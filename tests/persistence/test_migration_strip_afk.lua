local Migrations = require("WhisperMessenger.Persistence.Migrations")
local Schema = require("WhisperMessenger.Persistence.Schema")

return function()
  -- Simulate saved state with AFK/DND system messages mixed in
  local savedState = {
    schemaVersion = 2,
    conversations = {
      ["me::WOW::arthas-area52"] = {
        messages = {
          { id = "1", kind = "user", direction = "in", text = "hi", sentAt = 1, eventName = "CHAT_MSG_WHISPER" },
          {
            id = "2",
            kind = "system",
            direction = "in",
            text = "Away from keyboard",
            sentAt = 2,
            eventName = "CHAT_MSG_AFK",
          },
          {
            id = "3",
            kind = "user",
            direction = "out",
            text = "hello",
            sentAt = 3,
            eventName = "CHAT_MSG_WHISPER_INFORM",
          },
          {
            id = "4",
            kind = "system",
            direction = "in",
            text = "Do not disturb",
            sentAt = 4,
            eventName = "CHAT_MSG_DND",
          },
          { id = "5", kind = "user", direction = "in", text = "I'm back", sentAt = 5, eventName = "CHAT_MSG_WHISPER" },
        },
        unreadCount = 0,
        lastPreview = "I'm back",
        lastActivityAt = 5,
      },
      ["bnet::BN::42"] = {
        messages = {
          {
            id = "10",
            kind = "system",
            direction = "in",
            text = "Player offline",
            sentAt = 10,
            eventName = "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE",
          },
          { id = "11", kind = "system", direction = "in", text = "Away", sentAt = 11, eventName = "CHAT_MSG_AFK" },
        },
        unreadCount = 0,
        lastPreview = "Away",
        lastActivityAt = 11,
      },
    },
    contacts = {},
    pendingHydration = {},
  }

  local result = Migrations.Apply(savedState, Schema)

  -- AFK and DND messages should be stripped
  local arthasConv = result.conversations["me::WOW::arthas-area52"]
  assert(#arthasConv.messages == 3, "expected 3 messages after stripping AFK/DND, got " .. #arthasConv.messages)
  assert(arthasConv.messages[1].id == "1")
  assert(arthasConv.messages[2].id == "3")
  assert(arthasConv.messages[3].id == "5")

  -- Offline system message should be preserved
  local bnConv = result.conversations["bnet::BN::42"]
  assert(#bnConv.messages == 1, "expected 1 message after stripping AFK, got " .. #bnConv.messages)
  assert(bnConv.messages[1].id == "10", "offline message should be preserved")

  -- Conversation with no messages left should still exist
  assert(bnConv ~= nil, "conversation should still exist even with fewer messages")
end
