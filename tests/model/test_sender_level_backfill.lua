local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local SenderLevelBackfill = require("WhisperMessenger.Model.SenderLevelBackfill")

-- The player's realm is Kazzak: same-realm names lose their realm.
local function sameRealmAmbiguate(name, _context)
  return (string.gsub(name, "%-Kazzak$", ""))
end

local function line(fields)
  local message = { direction = "in", kind = "user", playerName = "Ishtarra-Kazzak" }
  for key, value in pairs(fields or {}) do
    message[key] = value
  end
  return message
end

local function storeWith(channel, message)
  return { conversations = { chat = { channel = channel, messages = { message } } } }
end

local function levels()
  return { [SeenLevel.NameKey("Ishtarra")] = 90 }
end

local function isEmpty(tbl)
  return next(tbl) == nil
end

return function()
  local savedAmbiguate = _G.Ambiguate
  rawset(_G, "Ambiguate", sameRealmAmbiguate)

  -- test_fills_nil_level_line_by_name
  do
    local message = line()
    local changed = SenderLevelBackfill.Apply(storeWith("CHANNEL", message), levels())
    assert(message.senderLevel == 90, "expected level 90, got " .. tostring(message.senderLevel))
    assert(changed.chat == true, "the conversation key should be returned")
  end

  -- test_raises_lower_level
  do
    local message = line({ senderLevel = 80 })
    SenderLevelBackfill.Apply(storeWith("GUILD", message), levels())
    assert(message.senderLevel == 90, "a lower level should rise to 90, got " .. tostring(message.senderLevel))
  end

  -- test_non_number_saved_level_is_replaced
  -- Saved data is a boundary: a corrupt level must not abort the walk.
  do
    local message = line({ senderLevel = "80" })
    local ok, changed = pcall(SenderLevelBackfill.Apply, storeWith("CHANNEL", message), levels())
    assert(ok, "a non-number saved level must not raise: " .. tostring(changed))
    assert(message.senderLevel == 90, "a non-number saved level should be replaced, got " .. tostring(message.senderLevel))
  end

  -- test_other_realm_namesake_stays_unset
  do
    local message = line({ playerName = "Ishtarra-Draenor" })
    local changed = SenderLevelBackfill.Apply(storeWith("CHANNEL", message), levels())
    assert(message.senderLevel == nil, "a namesake from another realm must stay unset")
    assert(isEmpty(changed), "nothing should be returned")
  end

  -- test_keeps_higher_level
  do
    local message = line({ senderLevel = 95 })
    local changed = SenderLevelBackfill.Apply(storeWith("CHANNEL", message), levels())
    assert(message.senderLevel == 95, "a higher level must never drop, got " .. tostring(message.senderLevel))
    assert(isEmpty(changed), "an unchanged conversation should not be returned")
  end

  -- test_skips_outgoing_line
  do
    local message = line({ direction = "out" })
    SenderLevelBackfill.Apply(storeWith("CHANNEL", message), levels())
    assert(message.senderLevel == nil, "outgoing lines get no sender level")
  end

  -- test_skips_whisper_and_bnet_chats
  do
    for _, channel in ipairs({ "WOW", "BN" }) do
      local message = line()
      local changed = SenderLevelBackfill.Apply(storeWith(channel, message), levels())
      assert(message.senderLevel == nil, channel .. " chats must be skipped")
      assert(isEmpty(changed), channel .. " chats must not be returned")
    end
  end

  -- test_conversation_without_messages_is_skipped
  do
    local store = { conversations = { chat = { channel = "CHANNEL" } } }
    local ok, changed = pcall(SenderLevelBackfill.Apply, store, levels())
    assert(ok, "a conversation without messages must not raise: " .. tostring(changed))
    assert(isEmpty(changed), "nothing should be returned")
  end

  -- test_only_named_player_changes
  do
    local message = line({ playerName = "Nergrom-Kazzak" })
    local map = levels()
    map[SeenLevel.NameKey("Jaina")] = 35
    SenderLevelBackfill.Apply(storeWith("CHANNEL", message), map)
    assert(message.senderLevel == nil, "a line from a player not in the reply must stay unset")
  end

  -- test_missing_store_returns_empty
  do
    assert(isEmpty(SenderLevelBackfill.Apply(nil, levels())), "no store should return an empty set")
  end

  rawset(_G, "Ambiguate", savedAmbiguate)
end
