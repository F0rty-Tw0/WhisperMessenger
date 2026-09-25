local ContactSearch = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactSearch")

-- Contact search finds conversations by the player's nickname and note.
return function()
  local items = {
    { conversationKey = "wow::arthas", displayName = "Arthas-Area52", nickname = "Big Boss", note = "Raid leader, Tuesdays" },
    { conversationKey = "wow::jaina", displayName = "Jaina-Area52" },
  }

  -- test_search_matches_nickname
  local byNickname = ContactSearch.BuildVisibleContacts(items, ContactSearch.NormalizeSearchQuery("boss"))
  assert(#byNickname == 1 and byNickname[1].conversationKey == "wow::arthas", "nickname matches")

  -- test_search_matches_note
  local byNote = ContactSearch.BuildVisibleContacts(items, ContactSearch.NormalizeSearchQuery("tuesdays"))
  assert(#byNote == 1 and byNote[1].conversationKey == "wow::arthas", "note matches")
end
