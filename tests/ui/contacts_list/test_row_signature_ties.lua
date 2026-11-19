-- Relationships carry a ties list the enricher may build afresh on every
-- refresh: rows compare its entries, not the table.

local RowSignature = require("WhisperMessenger.UI.ContactsList.RowSignature")
local FakeUI = require("tests.helpers.fake_ui")

local function newItem(ties)
  return {
    conversationKey = "me::BN::mike#1234",
    displayName = "Mike#1234",
    channel = "BN",
    lastActivityAt = 100,
    relationship = { primary = ties[1], ties = ties },
  }
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local options = {}

  local function stored(item)
    local row = {}
    RowSignature.Store(row, item, RowSignature.Context(parent, options))
    return row
  end

  local function matches(row, item)
    return RowSignature.Matches(row, item, RowSignature.Context(parent, options))
  end

  -- test_fresh_ties_list_with_the_same_ties_matches
  do
    local row = stored(newItem({ "bnet" }))
    assert(matches(row, newItem({ "bnet" })) == true, "an equal ties list in a new table should match")
  end

  -- test_another_tie_breaks_the_match
  do
    local row = stored(newItem({ "bnet" }))
    assert(matches(row, newItem({ "guild" })) == false, "a different tie should break the match")
  end

  -- test_added_tie_breaks_the_match
  do
    local row = stored(newItem({ "bnet" }))
    assert(matches(row, newItem({ "bnet", "guild" })) == false, "an added tie should break the match")
  end

  -- test_dropped_tie_breaks_the_match
  do
    local row = stored(newItem({ "bnet", "guild" }))
    assert(matches(row, newItem({ "bnet" })) == false, "a dropped tie should break the match")
  end

  -- test_ties_list_changed_in_place_breaks_the_match
  do
    local ties = { "bnet" }
    local item = newItem(ties)
    local row = stored(item)
    ties[2] = "guild"
    assert(matches(row, item) == false, "a tie added to the same table should break the match")
  end
end
