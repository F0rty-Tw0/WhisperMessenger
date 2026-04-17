local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  local options = {
    onSelect = function() end,
    onPin = function() end,
    onRemove = function() end,
  }

  local unpinnedItem = {
    conversationKey = "me::WOW::alice",
    displayName = "Alice",
    lastPreview = "hello",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    classTag = nil,
    pinned = false,
  }

  local pinnedItem = {
    conversationKey = "me::WOW::bob",
    displayName = "Bob",
    lastPreview = "hi",
    unreadCount = 0,
    lastActivityAt = 50,
    channel = "WOW",
    classTag = nil,
    pinned = true,
  }

  local function colorsMatch(a, b)
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
  end

  local transparent = { 0, 0, 0, 0 }

  -- test_unpinned_row_is_transparent_by_default
  do
    local row = RowView.bindRow(factory, parent, nil, 1, unpinnedItem, options)
    assert(row.bg ~= nil, "row should have bg texture")
    assert(colorsMatch(row.bg.color, transparent), "unpinned row should be transparent by default")
    assert((row.bg.color[4] or 0) == 0, "unpinned row base alpha should be 0")
  end

  -- test_pinned_row_uses_pinned_bg
  do
    local row = RowView.bindRow(factory, parent, nil, 1, pinnedItem, options)
    assert(colorsMatch(row.bg.color, Theme.COLORS.bg_contact_pinned), "pinned row should use bg_contact_pinned")
  end

  -- test_pinned_row_hover_uses_hover_bg
  do
    local row = RowView.bindRow(factory, parent, nil, 1, pinnedItem, options)
    row.scripts.OnEnter(row)
    assert(colorsMatch(row.bg.color, Theme.COLORS.bg_contact_hover), "pinned row hover should use bg_contact_hover")
  end

  -- test_pinned_row_leave_reverts_to_pinned_bg
  do
    local row = RowView.bindRow(factory, parent, nil, 1, pinnedItem, options)
    row.scripts.OnEnter(row)
    row.scripts.OnLeave(row)
    assert(
      colorsMatch(row.bg.color, Theme.COLORS.bg_contact_pinned),
      "pinned row should revert to bg_contact_pinned after leave"
    )
  end

  -- test_unpinned_row_leave_reverts_to_transparent
  do
    local row = RowView.bindRow(factory, parent, nil, 1, unpinnedItem, options)
    row.scripts.OnEnter(row)
    row.scripts.OnLeave(row)
    assert(colorsMatch(row.bg.color, transparent), "unpinned row should revert to transparent after leave")
  end

  print("PASS: test_row_view_pinned_bg")
end
