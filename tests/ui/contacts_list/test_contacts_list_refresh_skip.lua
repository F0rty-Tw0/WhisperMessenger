local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Theme = require("WhisperMessenger.UI.Theme")
local Relationship = require("WhisperMessenger.Model.Relationship")
local FakeUI = require("tests.helpers.fake_ui")

local function newItem(name, unreadCount)
  return {
    conversationKey = "me::WOW::" .. string.lower(name),
    displayName = name,
    lastPreview = "hello from " .. name,
    unreadCount = unreadCount or 0,
    lastActivityAt = 100,
    channel = "WOW",
    pinned = false,
  }
end

-- Counts name label writes: every bind sets the name, a skipped row doesn't.
local function countBinds(rows)
  local counts = {}
  for index, row in ipairs(rows) do
    counts[index] = 0
    local setText = row.title.SetText
    row.title.SetText = function(self, text)
      counts[index] = counts[index] + 1
      return setText(self, text)
    end
  end
  return counts
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  local function setup()
    local items = { newItem("Alice"), newItem("Bob"), newItem("Cara") }
    local options = { visibleCount = 3, selectedConversationKey = items[1].conversationKey }
    local rows = ContactsList.Refresh(factory, parent, {}, items, options)
    return items, options, rows
  end

  -- test_refresh_skips_bind_for_unchanged_row
  do
    local items, options, rows = setup()
    local counts = countBinds(rows)
    ContactsList.Refresh(factory, parent, rows, items, options)
    for index = 1, 3 do
      assert(counts[index] == 0, "row " .. index .. " should not rebind, got " .. counts[index] .. " name writes")
    end
  end

  -- test_refresh_rebinds_row_when_unread_count_changes
  do
    local items, options, rows = setup()
    local counts = countBinds(rows)
    items[2].unreadCount = 3
    ContactsList.Refresh(factory, parent, rows, items, options)
    assert(counts[2] > 0, "row with a new unread count should rebind")
    assert(counts[1] == 0 and counts[3] == 0, "unchanged rows should not rebind")
    assert(rows[2].unreadBadge.frame:IsShown() == true, "unread badge should show the new count")
  end

  -- test_refresh_rebinds_row_when_row_is_reassigned_to_another_conversation
  do
    local items, options, rows = setup()
    local counts = countBinds(rows)
    local moved = { items[3], items[1], items[2] }
    ContactsList.Refresh(factory, parent, rows, moved, options)
    for index = 1, 3 do
      assert(counts[index] > 0, "row " .. index .. " shows another conversation and should rebind")
      assert(rows[index].item == moved[index], "row " .. index .. " should hold its new item")
    end
    assert(rows[1].title.text == "Cara", "first row should now show Cara, got " .. tostring(rows[1].title.text))
  end

  -- test_refresh_rebinds_all_rows_when_theme_revision_changes
  do
    local previous = Theme.GetPreset()
    local items, options, rows = setup()
    local counts = countBinds(rows)
    Theme.SetPreset(previous == "wow_default" and "elvui_dark" or "wow_default")
    ContactsList.Refresh(factory, parent, rows, items, options)
    Theme.SetPreset(previous)
    for index = 1, 3 do
      assert(counts[index] > 0, "row " .. index .. " should rebind after a preset switch")
    end
  end

  -- test_skipped_row_takes_the_new_item_table
  do
    local items, options, rows = setup()
    local copy = {}
    for key, value in pairs(items[2]) do
      copy[key] = value
    end
    local nextItems = { items[1], copy, items[3] }
    ContactsList.Refresh(factory, parent, rows, nextItems, options)
    assert(rows[2].item == copy, "click and drag handlers read row.item, so it must be the new table")
  end

  -- test_selection_moves_on_skipped_rows
  do
    local items, options, rows = setup()
    options.selectedConversationKey = items[3].conversationKey
    ContactsList.Refresh(factory, parent, rows, items, options)
    assert(rows[1].selected == false, "old selection should clear")
    assert(rows[3].selected == true, "new selection should apply")
  end

  -- test_row_cleared_by_a_shorter_list_rebinds_when_it_comes_back
  do
    local items, options, rows = setup()
    ContactsList.Refresh(factory, parent, rows, { items[1] }, { visibleCount = 3, selectedConversationKey = options.selectedConversationKey })
    local counts = countBinds(rows)
    ContactsList.Refresh(factory, parent, rows, items, options)
    assert(counts[2] > 0 and counts[3] > 0, "blanked rows should rebind")
    assert(rows[2].title.text == "Bob", "row 2 should show Bob again, got " .. tostring(rows[2].title.text))
    assert(rows[2]:IsShown() == true, "row 2 should be shown again")
  end

  -- test_row_whose_bind_threw_rebinds_on_the_next_refresh
  do
    local items, options, rows = setup()
    local title = rows[2].title
    local setText = title.SetText
    title.SetText = function()
      error("bind failed")
    end
    items[2].pinned = true
    assert(pcall(ContactsList.Refresh, factory, parent, rows, items, options) == false, "the broken bind should throw")
    title.SetText = setText
    items[2].pinned = false
    local counts = countBinds(rows)
    ContactsList.Refresh(factory, parent, rows, items, options)
    assert(counts[2] > 0, "a half-painted row must rebind even when its old values come back")
  end

  -- test_offline_battle_net_row_skips_its_bind
  do
    local function bnetItem()
      local item = newItem("Mike#1234")
      item.channel = "BN"
      -- The enricher resolves the relationship afresh on every refresh.
      item.relationship = Relationship.Resolve(item, {})
      return item
    end
    local options = { visibleCount = 1 }
    local rows = ContactsList.Refresh(factory, parent, {}, { bnetItem() }, options)
    assert(rows[1].relationshipMark ~= nil, "an offline Battle.net friend should show the Battle.net mark")
    local counts = countBinds(rows)
    ContactsList.Refresh(factory, parent, rows, { bnetItem() }, options)
    assert(counts[1] == 0, "an unchanged Battle.net row should not rebind, got " .. counts[1] .. " name writes")
  end

  -- test_skipped_row_drops_hover_left_over_from_a_hidden_window
  do
    local items, options, rows = setup()
    local row = rows[2]
    row.mouseOver = true
    row:GetScript("OnEnter")(row)
    assert(row.pinButton:IsShown() == true, "hovering should show the pin button")
    -- The window hides under the pointer: no OnLeave arrives.
    row.mouseOver = false
    ContactsList.Refresh(factory, parent, rows, items, options)
    assert(row.pinButton:IsShown() == false, "pin button should hide once the pointer is gone")
    assert(row.removeButton:IsShown() == false, "remove button should hide once the pointer is gone")
  end
end
