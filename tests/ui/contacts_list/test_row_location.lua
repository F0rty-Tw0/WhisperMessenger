local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  -- test_create_location_sets_text_and_shows_when_area_name_present
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = { displayName = "Alice", areaName = "Voidscar Arena" }
    RowElements.createNameLabel(row, item, 260)
    local label = RowElements.createLocation(row, item, 260)
    assert(label ~= nil, "createLocation should return a FontString")
    assert(label.text == "Voidscar Arena", "location label should have areaName text, got: " .. tostring(label.text))
    assert(label:IsShown(), "location label should be shown when areaName present")
  end

  -- test_create_location_hidden_with_empty_text_when_area_name_nil
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = { displayName = "Bob", areaName = nil }
    RowElements.createNameLabel(row, item, 260)
    local label = RowElements.createLocation(row, item, 260)
    assert(label.text == "", "location label text should be empty when areaName nil, got: " .. tostring(label.text))
    assert(not label:IsShown(), "location label should be hidden when areaName nil")
  end

  -- test_update_location_flips_from_shown_to_hidden_on_rebind_without_area_name
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = { displayName = "Carol", areaName = "Stormwind" }
    RowElements.createNameLabel(row, item, 260)
    RowElements.createLocation(row, item, 260)
    assert(row.location:IsShown(), "location should be shown initially")

    local rebindItem = { displayName = "Carol", areaName = nil }
    RowElements.updateLocation(row, rebindItem, 260)
    assert(not row.location:IsShown(), "location should be hidden after rebind without areaName")
    assert(row.location.text == "", "location text should be cleared after rebind without areaName")
  end

  -- test_bind_row_shows_location_with_area_name
  do
    local options = {
      onSelect = function() end,
      onPin = function() end,
      onRemove = function() end,
    }
    local item = {
      conversationKey = "me::WOW::dave",
      displayName = "Dave",
      lastPreview = "hi",
      unreadCount = 0,
      lastActivityAt = 100,
      channel = "WOW",
      classTag = nil,
      pinned = false,
      areaName = "Voidscar Arena",
    }
    local row = RowView.bindRow(factory, parent, nil, 1, item, options)
    assert(row.location ~= nil, "bindRow should create row.location")
    assert(row.location.text == "Voidscar Arena", "row.location text should match areaName, got: " .. tostring(row.location.text))
    assert(row.location:IsShown(), "row.location should be shown")

    local rebindItem = {
      conversationKey = "me::WOW::dave",
      displayName = "Dave",
      lastPreview = "hi",
      unreadCount = 0,
      lastActivityAt = 100,
      channel = "WOW",
      classTag = nil,
      pinned = false,
      areaName = nil,
    }
    RowView.bindRow(factory, parent, row, 1, rebindItem, options)
    assert(not row.location:IsShown(), "row.location should hide after rebind without areaName")
  end

  -- test_bind_row_group_item_keeps_location_hidden_even_with_area_name
  do
    local options = {
      onSelect = function() end,
      onPin = function() end,
      onRemove = function() end,
    }
    local groupItem = {
      conversationKey = "me::GUILD::guild1",
      displayName = "Guild Chat",
      lastPreview = "hi",
      unreadCount = 0,
      lastActivityAt = 100,
      channel = ChannelType.GUILD,
      pinned = false,
      areaName = "Orgrimmar",
    }
    local row = RowView.bindRow(factory, parent, nil, 1, groupItem, options)
    assert(row.location ~= nil, "bindRow should create row.location for group row")
    assert(not row.location:IsShown(), "group row location should stay hidden even with areaName")
  end

  print("PASS: test_row_location")
end
