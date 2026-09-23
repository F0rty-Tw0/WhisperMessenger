rawset(_G, "time", os.time)
_G.date = os.date

local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")
local TimeFormat = require("WhisperMessenger.Util.TimeFormat")

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

  -- test_modern_action_buttons_hidden_on_selected_row_without_hover
  do
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    local ContactsList = require("WhisperMessenger.UI.ContactsList")
    ContactsList.SetSelected({ row }, item.conversationKey)
    assert(row.pinButton:IsShown() == false, "modern: pinButton hidden on a selected row that is not hovered")
    assert(row.removeButton:IsShown() == false, "modern: removeButton hidden on a selected row that is not hovered")
  end

  -- test_action_buttons_hidden_when_deselected
  do
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    local ContactsList = require("WhisperMessenger.UI.ContactsList")
    -- First select
    ContactsList.SetSelected({ row }, item.conversationKey)
    -- Then deselect
    ContactsList.SetSelected({ row }, "other::key")
    assert(row.pinButton:IsShown() == false, "pinButton should be hidden when row is deselected")
    assert(row.removeButton:IsShown() == false, "removeButton should be hidden when row is deselected")
  end

  -- test_modern_selected_row_actions_hide_after_hover_leave
  do
    Theme.SetPreset("wow_default")
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    local ContactsList = require("WhisperMessenger.UI.ContactsList")
    ContactsList.SetSelected({ row }, item.conversationKey)
    row.timeLabel:Show()
    row.mouseOver = true
    row.scripts.OnEnter(row)
    assert(row.removeButton:IsShown() == true, "modern: hover shows removeButton on the selected row")
    assert(row.timeLabel:IsShown() == true, "modern: timestamp stays while actions show")
    row.mouseOver = false
    row.scripts.OnLeave(row)
    assert(row.removeButton:IsShown() == false, "modern: leaving hides removeButton on the selected row")
    assert(row.timeLabel:IsShown() == true, "modern: timestamp back after leave")
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
    -- The pin action follows the hover-only rule on every preset.
    Theme.SetPreset("wow_native")
    local row = RowView.bindRow(factory, parent, nil, 1, pinnedItem, options)
    local ContactsList = require("WhisperMessenger.UI.ContactsList")
    ContactsList.SetSelected({ row }, pinnedItem.conversationKey)
    assert(row.pinButton:IsShown() == false, "modern: pinned chevron hidden on a selected, unhovered row")
    row.mouseOver = true
    row.scripts.OnEnter(row)
    assert(row.pinButton:IsShown() == true, "modern: pinned chevron shows on hover")
    row.mouseOver = false
    row.scripts.OnLeave(row)
    assert(row.pinButton:IsShown() == false, "modern: pinned chevron hides after leave")
  end
  -- test_session_labels_preserve_owner_prefix
  do
    local timestamp = os.time({ year = 2026, month = 12, day = 9, hour = 23, min = 33, sec = 0 })
    TimeFormat.Configure({ timeFormat = "24h", timeSource = "local" })

    local currentRow = RowView.bindRow(factory, parent, nil, 1, {
      conversationKey = "party::arthas-area52",
      displayName = "Party",
      lastPreview = "",
      lastActivityAt = 0,
      channel = "PARTY",
      leftGroup = false,
      pinned = false,
    }, options)
    assert(currentRow.title.text == "Party - Current", "current PARTY row should include Current")

    local foreignRow = RowView.bindRow(factory, parent, nil, 1, {
      conversationKey = "party::jaina-proudmoore",
      displayName = "Party",
      lastPreview = "",
      lastActivityAt = timestamp,
      channel = "PARTY",
      leftGroup = false,
      ownerProfileId = "jaina-proudmoore",
      pinned = false,
    }, options)
    assert(foreignRow.title.text == "Jaina - Party - 23:33 09/12", "foreign PARTY row should preserve owner prefix before historical session label")
    TimeFormat.Configure({ timeFormat = "12h", timeSource = "local" })
  end
end
