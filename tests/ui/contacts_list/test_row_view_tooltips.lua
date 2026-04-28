local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

-- Stub GameTooltip
local tooltipState = { text = nil, shown = false }
_G.GameTooltip = {
  SetOwner = function() end,
  SetText = function(_self, text)
    tooltipState.text = text
  end,
  Show = function()
    tooltipState.shown = true
  end,
  Hide = function()
    tooltipState.text = nil
    tooltipState.shown = false
  end,
}

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  local options = {
    onSelect = function() end,
    onPin = function() end,
    onRemove = function() end,
  }

  -- test_remove_button_shows_tooltip
  do
    local item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      lastPreview = "hello",
      unreadCount = 0,
      lastActivityAt = 100,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    }
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    tooltipState = { text = nil, shown = false }
    row.removeButton.scripts.OnEnter(row.removeButton)
    assert(tooltipState.shown == true, "tooltip should be shown on remove hover")
    assert(tooltipState.text == "Remove", "remove tooltip should say 'Remove', got: " .. tostring(tooltipState.text))

    row.removeButton.scripts.OnLeave(row.removeButton)
    assert(tooltipState.shown == false, "tooltip should hide on remove leave")
  end

  -- test_pin_button_shows_tooltip_for_unpinned
  do
    local item = {
      conversationKey = "me::WOW::bob",
      displayName = "Bob",
      lastPreview = "hi",
      unreadCount = 0,
      lastActivityAt = 50,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    }
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    tooltipState = { text = nil, shown = false }
    row.pinButton.scripts.OnEnter(row.pinButton)
    assert(tooltipState.shown == true, "tooltip should be shown on pin hover")
    assert(tooltipState.text == "Pin to top", "pin tooltip should say 'Pin to top', got: " .. tostring(tooltipState.text))

    row.pinButton.scripts.OnLeave(row.pinButton)
    assert(tooltipState.shown == false, "tooltip should hide on pin leave")
  end

  -- test_pin_button_shows_tooltip_for_pinned
  do
    local item = {
      conversationKey = "me::WOW::carol",
      displayName = "Carol",
      lastPreview = "hey",
      unreadCount = 0,
      lastActivityAt = 30,
      channel = "WOW",
      classTag = nil,
      pinned = true,
    }
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    tooltipState = { text = nil, shown = false }
    row.pinButton.scripts.OnEnter(row.pinButton)
    assert(tooltipState.shown == true, "tooltip should be shown on unpin hover")
    assert(tooltipState.text == "Unpin", "pin tooltip should say 'Unpin', got: " .. tostring(tooltipState.text))

    row.pinButton.scripts.OnLeave(row.pinButton)
    assert(tooltipState.shown == false, "tooltip should hide on unpin leave")
  end

  -- test_pin_button_updates_tooltip_when_row_reused_unpinned_to_pinned
  do
    local row = RowView.bindRow(factory, parent, nil, 1, {
      conversationKey = "me::WOW::dave",
      displayName = "Dave",
      lastPreview = "yo",
      unreadCount = 0,
      lastActivityAt = 20,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    }, options)

    row = RowView.bindRow(factory, parent, row, 1, {
      conversationKey = "me::WOW::dave",
      displayName = "Dave",
      lastPreview = "yo",
      unreadCount = 0,
      lastActivityAt = 20,
      channel = "WOW",
      classTag = nil,
      pinned = true,
    }, options)

    tooltipState = { text = nil, shown = false }
    row.pinButton.scripts.OnEnter(row.pinButton)
    assert(tooltipState.shown == true, "tooltip should be shown on reused pin hover")
    assert(tooltipState.text == "Unpin", "reused pinned row tooltip should say 'Unpin', got: " .. tostring(tooltipState.text))
  end

  -- test_pin_button_updates_tooltip_when_row_reused_pinned_to_unpinned
  do
    local row = RowView.bindRow(factory, parent, nil, 1, {
      conversationKey = "me::WOW::erin",
      displayName = "Erin",
      lastPreview = "sup",
      unreadCount = 0,
      lastActivityAt = 10,
      channel = "WOW",
      classTag = nil,
      pinned = true,
    }, options)

    row = RowView.bindRow(factory, parent, row, 1, {
      conversationKey = "me::WOW::erin",
      displayName = "Erin",
      lastPreview = "sup",
      unreadCount = 0,
      lastActivityAt = 10,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    }, options)

    tooltipState = { text = nil, shown = false }
    row.pinButton.scripts.OnEnter(row.pinButton)
    assert(tooltipState.shown == true, "tooltip should be shown on reused unpin hover")
    assert(tooltipState.text == "Pin to top", "reused unpinned row tooltip should say 'Pin to top', got: " .. tostring(tooltipState.text))
  end

  -- test_remove_button_restores_current_background_when_row_reused
  do
    local row = RowView.bindRow(factory, parent, nil, 1, {
      conversationKey = "me::WOW::fran",
      displayName = "Fran",
      lastPreview = "wave",
      unreadCount = 0,
      lastActivityAt = 5,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    }, options)

    row = RowView.bindRow(factory, parent, row, 1, {
      conversationKey = "me::WOW::fran",
      displayName = "Fran",
      lastPreview = "wave",
      unreadCount = 0,
      lastActivityAt = 5,
      channel = "WOW",
      classTag = nil,
      pinned = true,
    }, options)

    row.removeButton.scripts.OnEnter(row.removeButton)
    row.mouseOver = false
    row.removeButton.scripts.OnLeave(row.removeButton)

    local expected = Theme.COLORS.bg_contact_pinned
    local actual = row.bg.color
    assert(actual ~= nil, "row background color should be restored on remove leave")
    assert(
      actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3] and actual[4] == expected[4],
      "reused pinned row should restore pinned background color"
    )
  end
  print("PASS: test_row_view_tooltips")
end
