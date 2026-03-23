local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")

return function()
  -- test_pinned_contacts_sort_before_unpinned
  do
    local conversations = {
      ["me::WOW::alice"] = {
        displayName = "Alice",
        lastPreview = "hey",
        unreadCount = 0,
        lastActivityAt = 100,
        channel = "WOW",
        pinned = false,
      },
      ["me::WOW::bob"] = {
        displayName = "Bob",
        lastPreview = "hi",
        unreadCount = 0,
        lastActivityAt = 200,
        channel = "WOW",
        pinned = true,
      },
      ["me::WOW::carol"] = {
        displayName = "Carol",
        lastPreview = "yo",
        unreadCount = 0,
        lastActivityAt = 300,
        channel = "WOW",
        pinned = false,
      },
    }

    local items = DataBuilder.BuildItems(conversations)
    assert(#items == 3, "expected 3 items")
    -- Bob is pinned, should be first despite not having the latest activity
    assert(items[1].displayName == "Bob", "pinned contact should be first, got: " .. items[1].displayName)
    -- Unpinned sorted by lastActivityAt desc: Carol (300) then Alice (100)
    assert(items[2].displayName == "Carol", "second should be Carol, got: " .. items[2].displayName)
    assert(items[3].displayName == "Alice", "third should be Alice, got: " .. items[3].displayName)
  end

  -- test_pinned_contacts_sort_among_themselves_by_activity
  do
    local conversations = {
      ["me::WOW::dave"] = {
        displayName = "Dave",
        lastPreview = "a",
        unreadCount = 0,
        lastActivityAt = 50,
        channel = "WOW",
        pinned = true,
      },
      ["me::WOW::eve"] = {
        displayName = "Eve",
        lastPreview = "b",
        unreadCount = 0,
        lastActivityAt = 150,
        channel = "WOW",
        pinned = true,
      },
    }

    local items = DataBuilder.BuildItems(conversations)
    assert(items[1].displayName == "Eve", "pinned with newer activity first, got: " .. items[1].displayName)
    assert(items[2].displayName == "Dave", "pinned with older activity second, got: " .. items[2].displayName)
  end

  -- test_item_includes_pinned_flag
  do
    local conversations = {
      ["me::WOW::frank"] = {
        displayName = "Frank",
        lastPreview = "x",
        unreadCount = 0,
        lastActivityAt = 10,
        channel = "WOW",
        pinned = true,
      },
    }

    local items = DataBuilder.BuildItems(conversations)
    assert(items[1].pinned == true, "item should include pinned=true")
  end
end
