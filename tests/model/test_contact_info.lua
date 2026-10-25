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
end
