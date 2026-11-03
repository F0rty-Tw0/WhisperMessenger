rawset(_G, "time", rawget(_G, "time") or os.time)
rawset(_G, "date", rawget(_G, "date") or os.date)

local ConversationExport = require("WhisperMessenger.Model.ConversationExport")
local Localization = require("WhisperMessenger.Locale.Localization")

-- A conversation as plain text: a header line, then one
-- "[YYYY-MM-DD HH:MM] Name: text" line per message, oldest first.

local T1 = 1700000000
local T2 = T1 + 60

local function stamp(ts)
  return os.date("%Y-%m-%d %H:%M", ts)
end

local function lines(text)
  local result = {}
  for line in string.gmatch(text .. "\n", "(.-)\n") do
    result[#result + 1] = line
  end
  return result
end

local NAMES = { contactName = "Arthas", playerName = "Jaina" }

return function()
  Localization.Configure({ language = "enUS" })
  local savedSecret = rawget(_G, "issecretvalue")

  -- test_header_names_the_contact
  do
    local out = lines(ConversationExport.Format({}, NAMES))
    assert(out[1] == "Conversation with Arthas", "header line, got " .. tostring(out[1]))
  end

  -- test_empty_conversation_is_just_the_header
  do
    local out = lines(ConversationExport.Format({}, NAMES))
    assert(#out == 1, "empty conversation exports only the header, got " .. #out .. " lines")
  end

  -- test_messages_keep_their_order_one_line_each
  do
    local messages = {
      { direction = "in", kind = "user", text = "hi", sentAt = T1, playerName = "Arthas" },
      { direction = "in", kind = "user", text = "there", sentAt = T2, playerName = "Arthas" },
    }
    local out = lines(ConversationExport.Format(messages, NAMES))
    assert(out[2] == "[" .. stamp(T1) .. "] Arthas: hi", "first message line, got " .. tostring(out[2]))
    assert(out[3] == "[" .. stamp(T2) .. "] Arthas: there", "second message line, got " .. tostring(out[3]))
  end

  -- test_outgoing_lines_use_the_players_own_name
  do
    -- An outgoing record's playerName is the whisper target, not the sender.
    local messages = { { direction = "out", kind = "user", text = "yo", sentAt = T1, playerName = "Arthas" } }
    local out = lines(ConversationExport.Format(messages, NAMES))
    assert(out[2] == "[" .. stamp(T1) .. "] Jaina: yo", "outgoing line uses own name, got " .. tostring(out[2]))
  end

  -- test_text_loses_escape_codes_and_links_keep_labels
  do
    local text = "|cffff0000look|r |cffa335ee|Hitem:19019::|h[Thunderfury]|h|r|TInterface\\Icons\\X:16|t"
    local messages = { { direction = "in", kind = "user", text = text, sentAt = T1, playerName = "Arthas" } }
    local out = lines(ConversationExport.Format(messages, NAMES))
    assert(out[2] == "[" .. stamp(T1) .. "] Arthas: look [Thunderfury]", "plain text only, got " .. tostring(out[2]))
  end

  -- test_secret_and_non_string_text_is_skipped
  do
    local SECRET = {}
    rawset(_G, "issecretvalue", function(value)
      return value == SECRET
    end)
    local messages = {
      { direction = "in", kind = "user", text = SECRET, sentAt = T1, playerName = "Arthas" },
      { direction = "in", kind = "user", text = nil, sentAt = T1, playerName = "Arthas" },
      { direction = "in", kind = "user", text = "kept", sentAt = T2, playerName = "Arthas" },
    }
    local out = lines(ConversationExport.Format(messages, NAMES))
    rawset(_G, "issecretvalue", savedSecret)
    assert(#out == 2 and out[2] == "[" .. stamp(T2) .. "] Arthas: kept", "only the readable message is exported")
  end

  -- test_unsent_messages_are_skipped
  do
    local messages = { { direction = "out", kind = "user", text = "later", sentAt = T1, delivery = "queued" } }
    local out = lines(ConversationExport.Format(messages, NAMES))
    assert(#out == 1, "a queued or failed message was never said, so it is not exported")
  end

  -- test_protected_sender_name_falls_back_to_the_contact
  do
    local messages = { { direction = "in", kind = "user", text = "hey", sentAt = T1, playerName = "|Kq12|k" } }
    local out = lines(ConversationExport.Format(messages, NAMES))
    assert(out[2] == "[" .. stamp(T1) .. "] Arthas: hey", "protected name shows the contact, got " .. tostring(out[2]))
  end

  -- test_system_lines_have_no_sender
  do
    local messages = { { direction = "in", kind = "system", text = "Arthas joined.", sentAt = T1 } }
    local out = lines(ConversationExport.Format(messages, NAMES))
    assert(out[2] == "[" .. stamp(T1) .. "] Arthas joined.", "system line without a name, got " .. tostring(out[2]))
  end

  rawset(_G, "issecretvalue", savedSecret)
end
