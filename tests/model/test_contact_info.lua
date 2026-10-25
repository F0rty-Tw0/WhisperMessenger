local ContactInfo = require("WhisperMessenger.Model.ContactInfo")

local function makeRuntime()
  local runtime = {
    store = { conversations = { ["wow::WOW::jaina-proudmoore"] = { channel = "WOW", displayName = "Jaina-Proudmoore" } } },
  }
  runtime.contactInfo = ContactInfo.New()
  return runtime
end

return function()
  -- test_line_shows_for_the_matching_conversation
  do
    local runtime = makeRuntime()
    assert(ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "Craft Alert: Belt") == true)
    local lines = ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::jaina-proudmoore" })
    assert(#lines == 1 and lines[1] == "Craft Alert: Belt", "expected the one line, got " .. #lines)
  end

  -- test_other_conversation_gets_nothing
  do
    local runtime = makeRuntime()
    runtime.store.conversations["wow::WOW::arthas"] = { channel = "WOW", displayName = "Arthas" }
    ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "x")
    local lines = ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::arthas" })
    assert(#lines == 0, "another conversation shows nothing, got " .. #lines)
  end

  -- test_several_sources_one_line_each_in_source_key_order
  do
    local runtime = makeRuntime()
    ContactInfo.Set(runtime.contactInfo, "b", "Jaina-Proudmoore", "B text")
    ContactInfo.Set(runtime.contactInfo, "a", "Jaina-Proudmoore", "A text")
    local lines = ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::jaina-proudmoore" })
    assert(#lines == 2 and lines[1] == "A text" and lines[2] == "B text", "sorted by source key")
  end

  -- test_nil_text_removes_the_line
  do
    local runtime = makeRuntime()
    local contact = { conversationKey = "wow::WOW::jaina-proudmoore" }
    ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "x")
    assert(ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", nil) == true)
    assert(#ContactInfo.LinesFor(runtime, contact) == 0, "line removed")
    assert(next(runtime.contactInfo) == nil, "empty tables are dropped")
  end

  -- test_info_for_a_player_without_a_conversation_waits
  do
    local runtime = makeRuntime()
    assert(ContactInfo.Set(runtime.contactInfo, "ca", "Thrall", "x") == true)
    assert(#ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::jaina-proudmoore" }) == 0, "no Thrall conversation yet")
    runtime.store.conversations["wow::WOW::thrall"] = { channel = "WOW", displayName = "Thrall" }
    local lines = ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::thrall" })
    assert(#lines == 1 and lines[1] == "x", "shown once the conversation exists")
  end

  -- test_bad_arguments_return_false
  do
    local state = ContactInfo.New()
    local badKeys = { "", 5 }
    for _, bad in ipairs(badKeys) do
      assert(ContactInfo.Set(state, bad, "Jaina", "x") == false, "bad sourceKey " .. tostring(bad))
      assert(ContactInfo.Set(state, "ca", bad, "x") == false, "bad playerName " .. tostring(bad))
    end
    assert(ContactInfo.Set(state, "ca", "Jaina", 5) == false, "numeric text")
    assert(ContactInfo.Set(state, "ca", "Jaina", {}) == false, "table text")
    assert(next(state) == nil, "nothing stored")
  end

  -- test_no_contact_or_no_state_is_empty
  do
    local runtime = makeRuntime()
    ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "x")
    assert(#ContactInfo.LinesFor(runtime, nil) == 0, "no contact")
    runtime.contactInfo = nil
    assert(#ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::jaina-proudmoore" }) == 0, "no state")
  end

  -- test_two_spellings_of_one_chat_give_one_line_per_source
  do
    local runtime = makeRuntime()
    local contact = { conversationKey = "wow::WOW::jaina-proudmoore" }
    assert(ContactInfo.Set(runtime.contactInfo, "ca", "Jaina", "first", runtime) == true)
    assert(ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "second", runtime) == true)
    local lines = ContactInfo.LinesFor(runtime, contact)
    assert(#lines == 1 and lines[1] == "second", "a later Set replaces the other spelling's note, got " .. #lines)
    assert(runtime.contactInfo["jaina"] == nil, "the replaced note is gone")
    assert(ContactInfo.Set(runtime.contactInfo, "ca", "Jaina", nil, runtime) == true)
    assert(#ContactInfo.LinesFor(runtime, contact) == 0, "nil removes the source's note for every spelling")
    assert(next(runtime.contactInfo) == nil, "nothing left stored")
  end

  -- test_spellings_stored_before_the_conversation_exists_still_show_one_line
  do
    local runtime = makeRuntime()
    runtime.store.conversations = {}
    ContactInfo.Set(runtime.contactInfo, "ca", "Jaina", "base", runtime)
    ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "exact", runtime)
    runtime.store.conversations["wow::WOW::jaina-proudmoore"] = { channel = "WOW", displayName = "Jaina-Proudmoore" }
    local lines = ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::jaina-proudmoore" })
    assert(#lines == 1 and lines[1] == "exact", "one line per source, the full name wins, got " .. #lines)
  end

  -- test_blank_text_removes_the_note
  do
    local runtime = makeRuntime()
    ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "x", runtime)
    for _, blank in ipairs({ "", "   ", "\t\n" }) do
      ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "x", runtime)
      assert(ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", blank, runtime) == true, "blank is a removal")
      assert(next(runtime.contactInfo) == nil, "blank text stores nothing")
    end
  end

  -- test_text_is_capped_in_bytes_without_splitting_a_character
  do
    local runtime = makeRuntime()
    ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", string.rep("a", 254) .. string.char(195, 169) .. string.rep("b", 500), runtime)
    local lines = ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::jaina-proudmoore" })
    assert(#lines[1] == 254, "cut before the two-byte character that would pass the cap, got " .. #lines[1])
  end

  -- test_players_and_sources_are_capped
  do
    local state = ContactInfo.New()
    for index = 1, ContactInfo.MAX_PLAYERS do
      assert(ContactInfo.Set(state, "ca", "Player" .. index, "x") == true, "player " .. index)
    end
    assert(ContactInfo.Set(state, "ca", "OnePlayerTooMany", "x") == false, "a new player past the cap is refused")
    assert(ContactInfo.Set(state, "ca", "Player1", "y") == true, "an existing player can still change")
    assert(ContactInfo.Set(state, "ca", "Player2", nil) == true, "removal frees a slot")
    assert(ContactInfo.Set(state, "ca", "OnePlayerTooMany", "x") == true, "a freed slot takes a new player")

    local crowded = ContactInfo.New()
    for index = 1, ContactInfo.MAX_SOURCES do
      assert(ContactInfo.Set(crowded, "src" .. index, "Jaina", "x") == true, "source " .. index)
    end
    assert(ContactInfo.Set(crowded, "extra", "Jaina", "x") == false, "a new source past the cap is refused")
    assert(ContactInfo.Set(crowded, "src1", "Jaina", "y") == true, "an existing source can still change")
  end

  -- test_lines_for_does_not_scan_every_note_against_every_conversation
  do
    local runtime = makeRuntime()
    local reads = 0
    for index = 1, 100 do
      local data = { channel = "WOW", displayName = "Other" .. index }
      runtime.store.conversations["wow::WOW::other" .. index] = setmetatable({}, {
        __index = function(_, field)
          reads = reads + 1
          return data[field]
        end,
      })
    end
    for index = 1, ContactInfo.MAX_PLAYERS - 1 do
      ContactInfo.Set(runtime.contactInfo, "ca", "Stranger" .. index, "x")
    end
    ContactInfo.Set(runtime.contactInfo, "ca", "Jaina-Proudmoore", "x")
    reads = 0
    local lines = ContactInfo.LinesFor(runtime, { conversationKey = "wow::WOW::jaina-proudmoore" })
    assert(#lines == 1, "the selected chat still gets its line")
    assert(reads <= 1000, "conversation reads must not grow with the notes, got " .. reads)
  end
end
