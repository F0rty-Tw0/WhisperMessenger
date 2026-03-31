local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")

return function()
  -- test_conversation_snapshot_applies_defaults_and_preserves_metadata
  do
    local snapshot = ConversationSnapshot.Build("bnet::BN::jaina#1234", {
      contactDisplayName = "Jaina#1234",
      channel = "BN",
      guid = "Player-1-00000042",
      bnetAccountID = 42,
      battleTag = "Jaina#1234",
      gameAccountName = "Jaina",
      className = "Mage",
      classTag = "MAGE",
      raceName = "Human",
      raceTag = "Human",
      factionName = "Alliance",
      pinned = true,
      sortOrder = 7,
      messages = {
        { text = "Frostbolt ready", playerName = "Jaina" },
        { text = "Meet at Dalaran", playerName = "Khadgar" },
      },
    })

    assert(snapshot.conversationKey == "bnet::BN::jaina#1234", "conversationKey should be preserved")
    assert(snapshot.displayName == "Jaina#1234", "displayName should fall back to contactDisplayName")
    assert(snapshot.lastPreview == "", "lastPreview should default to empty string")
    assert(type(snapshot.searchText) == "string", "searchText should be a string")
    assert(
      string.find(snapshot.searchText, "jaina#1234", 1, true) ~= nil,
      "searchText should include lowercased display name"
    )
    assert(
      string.find(snapshot.searchText, "frostbolt ready", 1, true) ~= nil,
      "searchText should include message text"
    )
    assert(string.find(snapshot.searchText, "khadgar", 1, true) ~= nil, "searchText should include sender names")
    assert(snapshot.unreadCount == 0, "unreadCount should default to 0")
    assert(snapshot.lastActivityAt == 0, "lastActivityAt should default to 0")
    assert(snapshot.channel == "BN", "channel should be preserved")
    assert(snapshot.guid == "Player-1-00000042", "guid should be preserved")
    assert(snapshot.bnetAccountID == 42, "bnetAccountID should be preserved")
    assert(snapshot.battleTag == "Jaina#1234", "battleTag should be preserved")
    assert(snapshot.gameAccountName == "Jaina", "gameAccountName should be preserved")
    assert(snapshot.className == "Mage", "className should be preserved")
    assert(snapshot.classTag == "MAGE", "classTag should be preserved")
    assert(snapshot.raceName == "Human", "raceName should be preserved")
    assert(snapshot.raceTag == "Human", "raceTag should be preserved")
    assert(snapshot.factionName == "Alliance", "factionName should be preserved")
    assert(snapshot.pinned == true, "pinned should be preserved")
    assert(snapshot.sortOrder == 7, "sortOrder should be preserved")
  end

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

  -- test_sort_order_overrides_activity_within_pinned_group
  do
    local conversations = {
      ["me::WOW::p1"] = {
        displayName = "P1",
        lastPreview = "a",
        unreadCount = 0,
        lastActivityAt = 100,
        channel = "WOW",
        pinned = true,
        sortOrder = 2,
      },
      ["me::WOW::p2"] = {
        displayName = "P2",
        lastPreview = "b",
        unreadCount = 0,
        lastActivityAt = 200,
        channel = "WOW",
        pinned = true,
        sortOrder = 1,
      },
    }

    local items = DataBuilder.BuildItems(conversations)
    -- P2 has sortOrder=1, P1 has sortOrder=2 → P2 first
    assert(items[1].displayName == "P2", "lower sortOrder first in pinned group, got: " .. items[1].displayName)
    assert(items[2].displayName == "P1", "higher sortOrder second in pinned group, got: " .. items[2].displayName)
  end

  -- test_sort_order_ignored_for_unpinned_contacts
  do
    local conversations = {
      ["me::WOW::u1"] = {
        displayName = "U1",
        lastPreview = "a",
        unreadCount = 0,
        lastActivityAt = 300,
        channel = "WOW",
        sortOrder = 2,
      },
      ["me::WOW::u2"] = {
        displayName = "U2",
        lastPreview = "b",
        unreadCount = 0,
        lastActivityAt = 100,
        channel = "WOW",
        sortOrder = 1,
      },
    }

    local items = DataBuilder.BuildItems(conversations)
    -- Unpinned ignores sortOrder, uses lastActivityAt desc
    assert(items[1].displayName == "U1", "unpinned should sort by activity: U1 first, got: " .. items[1].displayName)
    assert(items[2].displayName == "U2", "unpinned should sort by activity: U2 second, got: " .. items[2].displayName)
  end

  -- test_zero_sort_order_falls_back_to_activity
  do
    local conversations = {
      ["me::WOW::z1"] = {
        displayName = "Z1",
        lastPreview = "a",
        unreadCount = 0,
        lastActivityAt = 100,
        channel = "WOW",
        sortOrder = 0,
      },
      ["me::WOW::z2"] = {
        displayName = "Z2",
        lastPreview = "b",
        unreadCount = 0,
        lastActivityAt = 200,
        channel = "WOW",
        sortOrder = 0,
      },
    }

    local items = DataBuilder.BuildItems(conversations)
    -- Both sortOrder=0, falls back to lastActivityAt desc
    assert(items[1].displayName == "Z2", "activity fallback: Z2 first, got: " .. items[1].displayName)
    assert(items[2].displayName == "Z1", "activity fallback: Z1 second, got: " .. items[2].displayName)
  end

  -- test_item_includes_sort_order
  do
    local conversations = {
      ["me::WOW::so1"] = {
        displayName = "SO1",
        lastPreview = "x",
        unreadCount = 0,
        lastActivityAt = 10,
        channel = "WOW",
        sortOrder = 7,
      },
    }

    local items = DataBuilder.BuildItems(conversations)
    assert(items[1].sortOrder == 7, "item should include sortOrder=7, got: " .. tostring(items[1].sortOrder))
  end
end
