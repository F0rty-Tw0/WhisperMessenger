local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")

-- Party-free group chats are account-wide: every character lists them.
return function()
  -- test_group_chat_rows_are_listed
  do
    local items = DataBuilder.BuildItemsForProfile({
      conversations = {
        ["wmgroup::abcd1234"] = { channel = "WM_GROUP", title = "Crew", displayName = "Crew", lastActivityAt = 5 },
        ["unknown::x"] = { channel = "WOW", displayName = "Ghost" },
      },
    }, "me-kazzak")
    assert(#items == 1, "only the group chat row, got " .. #items)
    assert(items[1].conversationKey == "wmgroup::abcd1234" and items[1].channel == "WM_GROUP")
    assert(items[1].ownerProfileId == nil, "a group chat belongs to no single character")
  end
end
