local SentHistory = require("WhisperMessenger.Model.SentHistory")

local function out(text, sentAt, extra)
  local message = { kind = "user", direction = "out", text = text, sentAt = sentAt }
  for key, value in pairs(extra or {}) do
    message[key] = value
  end
  return message
end

local function chat(messages)
  return { ["me::WOW::arthas"] = { messages = messages } }
end

local function same(list, expected, label)
  assert(#list == #expected, label .. ": expected " .. #expected .. " entries, got " .. #list)
  for index, text in ipairs(expected) do
    assert(list[index] == text, label .. ": entry " .. index .. " expected " .. tostring(text) .. ", got " .. tostring(list[index]))
  end
end

local function shortOnly(text)
  return #text <= 3
end

return function()
  -- test_keeps_only_own_sent_lines
  do
    local list = SentHistory.Build(chat({
      { kind = "user", direction = "in", text = "theirs", sentAt = 1 },
      out("mine", 2),
      { kind = "system", direction = "out", text = "status", sentAt = 3 },
    }))
    same(list, { "mine" }, "own sent lines only")
  end

  -- test_includes_other_characters_lines
  do
    local list = SentHistory.Build(chat({ out("a", 1, { profileId = "char-1" }), out("b", 2, { profileId = "char-2" }) }))
    same(list, { "b", "a" }, "other characters' lines")
  end

  -- test_includes_queued_and_failed_lines
  do
    local list = SentHistory.Build(chat({ out("q", 1, { delivery = "queued" }), out("f", 2, { delivery = "failed" }) }))
    same(list, { "f", "q" }, "queued and failed lines")
  end

  -- test_skips_secret_non_string_and_empty_text
  do
    local saved = rawget(_G, "issecretvalue")
    rawset(_G, "issecretvalue", function(value)
      return value == "SECRET"
    end)
    local list = SentHistory.Build(chat({ out("SECRET", 4), out(42, 3), out("", 2), out("ok", 1) }))
    rawset(_G, "issecretvalue", saved)
    same(list, { "ok" }, "secret, non-string and empty text skipped")
  end

  -- test_newest_first_across_chats
  do
    local list = SentHistory.Build({
      ["me::WOW::a"] = { messages = { out("a1", 10), out("a3", 30) } },
      ["me::WOW::b"] = { messages = { out("b2", 20) } },
    })
    same(list, { "a3", "b2", "a1" }, "newest first across chats")
  end

  -- test_nan_time_does_not_hide_out_of_order_lines
  do
    local list = SentHistory.Build({
      ["me::WOW::k"] = {
        messages = { out("five", 5), { kind = "user", direction = "in", text = "x", sentAt = 0 / 0 }, out("three", 3) },
      },
      ["me::WOW::j"] = { messages = { out("four", 4) } },
    })
    same(list, { "five", "four", "three" }, "NaN time between out-of-order lines")
  end

  -- test_same_second_lines_keep_send_order
  do
    local list = SentHistory.Build(chat({ out("first", 5), out("second", 5) }))
    same(list, { "second", "first" }, "same-second lines")
  end

  -- test_collapses_neighbouring_duplicates
  do
    local list = SentHistory.Build(chat({ out("ok", 1), out("hm", 2), out("ok", 3), out("ok", 4) }))
    same(list, { "ok", "hm", "ok" }, "neighbouring duplicates collapse")
  end

  -- test_drops_lines_fits_rejects
  do
    local list = SentHistory.Build(chat({ out("long one", 2), out("abc", 1) }), shortOnly)
    same(list, { "abc" }, "lines the chat refuses are dropped")
  end

  -- test_filter_runs_before_collapse
  do
    local list = SentHistory.Build(chat({ out("A", 1), out("BBBB", 2), out("A", 3) }), shortOnly)
    same(list, { "A" }, "a dropped line does not split a duplicate run")
  end

  -- test_secret_line_never_reaches_fits
  do
    local saved = rawget(_G, "issecretvalue")
    rawset(_G, "issecretvalue", function(value)
      return value == "SECRET"
    end)
    local fitsSawSecret = false
    local function recordingFits(text)
      if text == "SECRET" then
        fitsSawSecret = true
      end
      return true
    end
    local ok, err = pcall(SentHistory.Build, chat({ out("SECRET", 2), out("ok", 1) }), recordingFits)
    rawset(_G, "issecretvalue", saved)
    assert(ok, err)
    assert(fitsSawSecret == false, "fits must never be called with a secret line")
  end

  -- test_max_entries_is_fifty
  do
    assert(SentHistory.MAX_ENTRIES == 50, "cap is 50, got " .. tostring(SentHistory.MAX_ENTRIES))
  end

  local function sixtyLines()
    local messages = {}
    for index = 1, 60 do
      messages[index] = out("line" .. index, index)
    end
    return SentHistory.Build(chat(messages))
  end

  -- test_list_stops_at_max_entries
  do
    local list = sixtyLines()
    assert(#list == 50, "list capped at 50, got " .. #list)
  end

  -- test_capped_list_starts_with_newest_line
  do
    local list = sixtyLines()
    assert(list[1] == "line60", "newest kept first, got " .. tostring(list[1]))
  end

  -- test_capped_list_ends_with_fiftieth_newest_line
  do
    local list = sixtyLines()
    assert(list[50] == "line11", "oldest kept is the 50th newest, got " .. tostring(list[50]))
  end

  -- test_empty_store_gives_empty_list
  do
    assert(#SentHistory.Build({}) == 0, "empty store")
  end

  -- test_nil_store_gives_empty_list
  do
    assert(#SentHistory.Build(nil) == 0, "nil store")
  end

  -- test_chat_without_messages_gives_empty_list
  do
    assert(#SentHistory.Build({ ["me::WOW::x"] = { messages = nil } }) == 0, "chat without messages")
  end
end
