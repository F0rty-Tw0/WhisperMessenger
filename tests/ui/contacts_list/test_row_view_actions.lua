local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()

  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

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

  local pinnedKey
  local removedKey

  local options = {
    onSelect = function() end,
    onPin = function(it)
      pinnedKey = it.conversationKey
    end,
    onRemove = function(it)
      removedKey = it.conversationKey
    end,
  }

  -- test_row_has_pin_and_remove_buttons
  do
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    assert(row.pinButton ~= nil, "row should have pinButton")
    assert(row.removeButton ~= nil, "row should have removeButton")
  end

  -- test_action_buttons_anchor_below_timestamp
  do
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    local actionSpacing = Theme.LAYOUT.CONTACT_ACTION_SPACING

    assert(row.timeLabel ~= nil, "row should have timeLabel before action button anchoring")
    assert(row.removeButton.point ~= nil, "removeButton should have point")
    assert(row.removeButton.point[1] == "TOPRIGHT", "removeButton should anchor TOPRIGHT")
    assert(row.removeButton.point[2] == row.timeLabel, "removeButton should anchor to time label")
    assert(row.removeButton.point[3] == "BOTTOMRIGHT", "removeButton should sit below time label")
    assert(row.removeButton.point[5] == -actionSpacing, "removeButton should be offset below time label")

    assert(row.pinButton.point ~= nil, "pinButton should have point")
    assert(row.pinButton.point[1] == "TOP", "pinButton should anchor TOP")
    assert(row.pinButton.point[2] == row.removeButton, "pinButton should anchor to removeButton")
    assert(row.pinButton.point[3] == "BOTTOM", "pinButton should sit below removeButton")
    assert(row.pinButton.point[5] == -actionSpacing + 8, "pinButton should be offset below removeButton")
  end

  -- test_action_buttons_hidden_by_default
  do
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    assert(row.pinButton:IsShown() == false, "pinButton should be hidden by default")
    assert(row.removeButton:IsShown() == false, "removeButton should be hidden by default")
  end

  -- test_action_buttons_show_on_hover
  do
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    -- Simulate mouse enter
    local onEnter = row.scripts and row.scripts.OnEnter
    assert(onEnter ~= nil, "row should have OnEnter handler")
    onEnter(row)
    assert(row.pinButton:IsShown() == true, "pinButton should show on hover")
    assert(row.removeButton:IsShown() == true, "removeButton should show on hover")
  end

  -- test_action_buttons_hide_on_leave
  do
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    local onEnter = row.scripts.OnEnter
    local onLeave = row.scripts.OnLeave
    onEnter(row)
    onLeave(row)
    assert(row.pinButton:IsShown() == false, "pinButton should hide on leave")
    assert(row.removeButton:IsShown() == false, "removeButton should hide on leave")
  end

  -- test_pin_button_click_fires_callback
  do
    pinnedKey = nil
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    local onClick = row.pinButton.scripts and row.pinButton.scripts.OnClick
    assert(onClick ~= nil, "pinButton should have OnClick")
    onClick(row.pinButton)
    assert(pinnedKey == "me::WOW::alice", "onPin should fire with item key, got: " .. tostring(pinnedKey))
  end

  -- test_remove_button_click_fires_callback
  do
    removedKey = nil
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    local onClick = row.removeButton.scripts and row.removeButton.scripts.OnClick
    assert(onClick ~= nil, "removeButton should have OnClick")
    onClick(row.removeButton)
    assert(removedKey == "me::WOW::alice", "onRemove should fire with item key, got: " .. tostring(removedKey))
  end

  -- test_action_buttons_stay_visible_when_mouse_moves_to_child_button
  -- WoW event order: Row OnLeave fires, then Button OnEnter fires (same frame).
  -- The deferred Row OnLeave visual update runs next frame, after Button OnEnter.
  -- In tests (no C_Timer), Row OnLeave runs immediately, then Button OnEnter re-shows.
  do
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    local onEnter = row.scripts.OnEnter
    local onLeave = row.scripts.OnLeave

    -- Mouse enters row
    onEnter(row)
    assert(row.pinButton:IsShown() == true, "buttons show on row hover")

    -- Mouse moves to child button: Row OnLeave then Button OnEnter
    onLeave(row)
    row.removeButton.scripts.OnEnter(row.removeButton)

    assert(row.pinButton:IsShown() == true, "pinButton should stay visible when action button hovered")
    assert(row.removeButton:IsShown() == true, "removeButton should stay visible when action button hovered")

    -- Mouse leaves button going outside row entirely
    row.removeButton.scripts.OnLeave(row.removeButton)

    assert(row._wmRowHover == false, "row hover flag should be cleared")
    assert(row.pinButton:IsShown() == false, "pinButton should hide when mouse truly leaves")
    assert(row.removeButton:IsShown() == false, "removeButton should hide when mouse truly leaves")
  end

  -- test_pinned_item_shows_pin_icon_active
  do
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
    local row = RowView.bindRow(factory, parent, nil, 1, pinnedItem, options)
    -- Pinned items should always show the pin icon
    assert(row.pinButton:IsShown() == true, "pinButton should be visible for pinned items")
  end
end
