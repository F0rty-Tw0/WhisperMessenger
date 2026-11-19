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

  -- test_caps_at_max_entries
  do
    local messages = {}
    for index = 1, 60 do
      messages[index] = out("line" .. index, index)
    end
    local list = SentHistory.Build(chat(messages))
    assert(SentHistory.MAX_ENTRIES == 50, "cap is 50")
    assert(#list == 50, "list capped at 50, got " .. #list)
    assert(list[1] == "line60", "newest kept first")
    assert(list[50] == "line11", "oldest kept is the 50th newest")
  end

  -- test_empty_store_gives_empty_list
  do
    assert(#SentHistory.Build({}) == 0, "empty store")
    assert(#SentHistory.Build(nil) == 0, "nil store")
    assert(#SentHistory.Build({ ["me::WOW::x"] = { messages = nil } }) == 0, "chat without messages")
  end
end
