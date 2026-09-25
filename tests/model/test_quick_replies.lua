local QuickReplies = require("WhisperMessenger.Model.QuickReplies")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  Localization.Configure({ language = "enUS" })

  -- test_unset_list_uses_default_replies
  local defaults = QuickReplies.List(nil)
  assert(#defaults == 4, "four default replies")
  assert(defaults[1] == "One sec" and defaults[2] == "On my way" and defaults[3] == "Sure!", "default replies in order")
  assert(defaults[4] == "Sorry, busy right now — will reply soon", "busy default reply")

  -- test_defaults_are_localized
  Localization.Configure({ language = "deDE" })
  assert(QuickReplies.List(nil)[1] ~= "One sec", "defaults follow the interface language")
  Localization.Configure({ language = "enUS" })

  -- test_saved_list_wins_even_when_empty
  local saved = { "brb" }
  assert(QuickReplies.List(saved) == saved, "saved replies are used as-is")
  assert(#QuickReplies.List({}) == 0, "an emptied list stays empty")

  -- test_add_appends_trimmed_text_without_mutating_input
  local added = assert(QuickReplies.Add(saved, "  gg wp  "))
  assert(added[1] == "brb" and added[2] == "gg wp", "add trims and appends")
  assert(#saved == 1, "add returns a new list")

  -- test_add_starts_from_defaults_when_unset
  local fromDefaults = assert(QuickReplies.Add(nil, "brb"))
  assert(#fromDefaults == 5 and fromDefaults[5] == "brb", "first edit keeps the defaults")

  -- test_add_rejects_blank_text
  assert(QuickReplies.Add(saved, "   ") == nil, "blank reply rejected")
  assert(QuickReplies.Add(saved, nil) == nil, "nil reply rejected")

  -- test_add_caps_length_at_255_bytes
  local long = assert(QuickReplies.Add({}, string.rep("a", 300)))
  assert(#long[1] == 255, "reply capped to 255 bytes, got " .. #long[1])

  -- test_add_refuses_past_ten_entries
  local full = {}
  for index = 1, QuickReplies.MAX_ENTRIES do
    full[index] = "r" .. index
  end
  assert(QuickReplies.MAX_ENTRIES == 10, "max ten replies")
  assert(QuickReplies.Add(full, "one more") == nil, "eleventh reply rejected")
  assert(QuickReplies.CanAdd(full) == false and QuickReplies.CanAdd(saved) == true, "CanAdd reports room")

  -- test_remove_drops_one_entry
  local removed = QuickReplies.Remove({ "a", "b", "c" }, 2)
  assert(#removed == 2 and removed[1] == "a" and removed[2] == "c", "remove drops the entry")
  local removedDefault = QuickReplies.Remove(nil, 1)
  assert(#removedDefault == 3 and removedDefault[1] == "On my way", "remove works from defaults")
end
