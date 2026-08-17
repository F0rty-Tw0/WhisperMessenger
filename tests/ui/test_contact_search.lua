local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local ContactSearch = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactSearch")

return function()
  -- test_snapshot_and_empty_query_do_not_read_message_history
  do
    local reads = 0
    local message = setmetatable({}, {
      __index = function(_, key)
        reads = reads + 1
        if key == "text" then
          return "Old retained message"
        end
        if key == "playerName" then
          return "Khadgar"
        end
      end,
    })
    local conversation = {
      displayName = "Jaina-Proudmoore",
      messages = { message },
    }
    local items = DataBuilder.BuildItems({
      ["me::WOW::jaina-proudmoore"] = conversation,
    })

    assert(reads == 0, "building contacts must not read retained message fields; reads: " .. reads)
    assert(items[1].searchText == nil, "snapshot must not build a persisted-style full-history search string")
    assert(items[1].conversation == conversation, "snapshot should retain its transient conversation reference")

    local visible = ContactSearch.BuildVisibleContacts(items, "")
    assert(#visible == 1, "empty query should retain the contact")
    assert(reads == 0, "empty query must not scan message history")
  end

  -- test_search_matches_metadata_and_retained_history_after_live_changes
  do
    local conversation = {
      displayName = "Arthas-Area52",
      battleTag = "Jaina#1234",
      gameAccountName = "ArcaneAvatar",
      messages = {
        { text = "Meet in Stormwind", playerName = "Khadgar" },
        { text = "Old retained message", playerName = "Anduin" },
      },
    }
    local items = DataBuilder.BuildItems({
      ["me::WOW::arthas-area52"] = conversation,
    })

    local function visibleFor(query)
      return ContactSearch.BuildVisibleContacts(items, ContactSearch.NormalizeSearchQuery(query))
    end
    assert(#visibleFor("1234") == 1, "search should match battle tags")
    assert(#visibleFor("arcaneavatar") == 1, "search should match game account names")
    assert(#visibleFor("old retained") == 1, "search should match every retained message")
    assert(#visibleFor("JAINA stormwind") == 1, "multi-term case-insensitive search should combine metadata and message text")
    assert(#visibleFor("KHADGAR") == 1, "search should match retained message senders")

    table.insert(conversation.messages, { text = "Argent Tournament", playerName = "Tirion" })
    assert(#visibleFor("argent") == 1, "appended message text should become searchable immediately")

    table.remove(conversation.messages, 2)
    assert(#visibleFor("old retained") == 0, "trimmed message text should stop matching immediately")
  end
end
