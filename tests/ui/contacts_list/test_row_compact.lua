local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local ActionButtons = require("WhisperMessenger.UI.ContactsList.ActionButtons")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local RAIL_ROW_PARENT_WIDTH = 46

local function person(overrides)
  local item = {
    conversationKey = "me::WOW::jaina",
    displayName = "Jaina-Proudmoore",
    lastPreview = "hello there",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    classTag = "MAGE",
    areaName = "Dalaran",
    availability = { status = "CanWhisper", canWhisper = true },
  }
  for key, value in pairs(overrides or {}) do
    item[key] = value
  end
  return item
end

local function newParent(factory, width)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(width, 400)
  return parent
end

return function()
  local factory = FakeUI.NewFactory()
  local compact = { compact = true }

  -- test_compact_row_hides_every_text_line
  do
    local parent = newParent(factory, 260)
    local row = RowView.bindRow(factory, parent, nil, 1, person({ muted = true }), {})
    -- Font strings start shown in the game (fakes start hidden).
    row.title:Show()
    row.preview:Show()
    row.timeLabel:Show()
    parent:SetSize(RAIL_ROW_PARENT_WIDTH, 400)
    row = RowView.bindRow(factory, parent, row, 1, person({ muted = true }), compact)
    assert(row.title.shown == false, "name hidden")
    assert(row.preview.shown == false, "preview hidden")
    assert(row.timeLabel.shown == false, "time hidden")
    assert(row.location.shown == false, "zone hidden")
    assert(row.factionIcon.shown == false, "faction icon hidden")
    assert(row.mutedMarker.shown == false, "muted marker hidden")
  end

  -- test_compact_person_row_shows_its_class_icon_dimmed_with_initials
  do
    local row = RowView.bindRow(factory, newParent(factory, RAIL_ROW_PARENT_WIDTH), nil, 1, person(), compact)
    assert(row.classIcon.texturePath == Theme.ClassIcon("MAGE"), "same class art as the full list")
    assert(row.classIcon.vertexColor[1] < 1, "class art dimmed under the initials")
    assert(row.railAvatar.label.text == "JA", "avatar shows the initials, got " .. tostring(row.railAvatar.label.text))
    assert(row.statusDot.shown == true, "status dot stays on people")
    local point, relativeTo = row.classIconFrame:GetPoint()
    assert(point == "CENTER" and relativeTo == row, "icon is centred in the rail row, got " .. tostring(point))
  end

  -- test_compact_unread_badge_sits_on_the_icon_corner
  do
    local row = RowView.bindRow(factory, newParent(factory, RAIL_ROW_PARENT_WIDTH), nil, 1, person({ unreadCount = 3 }), compact)
    local point, relativeTo, relativePoint = row.unreadBadge.frame:GetPoint()
    assert(point == "TOPRIGHT" and relativeTo == row.classIconFrame and relativePoint == "TOPRIGHT", "badge on the icon's top-right")
    assert(row.unreadBadge.frame.shown == true, "badge shows the unread count")
  end

  -- test_compact_row_never_shows_hover_actions_or_pinned_marker
  do
    local row = RowView.bindRow(factory, newParent(factory, RAIL_ROW_PARENT_WIDTH), nil, 1, person({ pinned = true }), compact)
    ActionButtons.showActions(row)
    assert(row.pinButton.shown == false and row.removeButton.shown == false, "no pin/remove buttons in the rail")
    assert(row.pinnedMarker == nil or row.pinnedMarker.shown == false, "no pinned marker in the rail")
  end

  -- test_compact_group_row_keeps_its_art_in_the_squircle
  do
    local group = { conversationKey = "guild::me", displayName = "Guild", channel = ChannelType.GUILD, unreadCount = 0, lastActivityAt = 1 }
    local row = RowView.bindRow(factory, newParent(factory, RAIL_ROW_PARENT_WIDTH), nil, 1, group, compact)
    assert(row.classIcon.texturePath == Theme.ChannelIcon(ChannelType.GUILD), "group keeps its achievement art")
    assert(row.classIcon.mask ~= nil and row.classIconFrame.clipsChildren == true, "in the same squircle as the class icons")
    assert(row.railGroupIcon == nil, "no separate square group art")
    assert(row.railAvatar == nil or row.railAvatar.label.shown == false, "no initials on a group")
    assert(row.classIcon.vertexColor == nil or row.classIcon.vertexColor[1] == 1, "group art not dimmed")
    assert(row.statusDot.shown == false, "no status dot on a group")
  end

  local trade =
    { conversationKey = "channel::me-realm::trade", displayName = "Trade", channel = ChannelType.CHANNEL, unreadCount = 0, lastActivityAt = 1 }

  -- test_channel_row_shows_its_own_channel_icon
  do
    local row = RowView.bindRow(factory, newParent(factory, 260), nil, 1, trade, {})
    assert(row.classIcon.texturePath == "Interface\\ICONS\\INV_Misc_Coin_01", "Trade icon, got " .. tostring(row.classIcon.texturePath))
  end

  -- test_rebinding_expanded_restores_the_full_row
  do
    local parent = newParent(factory, RAIL_ROW_PARENT_WIDTH)
    local row = RowView.bindRow(factory, parent, nil, 1, person({ unreadCount = 2 }), compact)
    parent:SetSize(260, 400)
    row = RowView.bindRow(factory, parent, row, 1, person({ unreadCount = 2 }), {})
    assert(row.title.shown == true and row.preview.shown == true and row.timeLabel.shown == true, "text lines back")
    assert(row.classIcon.texturePath == Theme.ClassIcon("MAGE"), "class icon art kept")
    assert(row.classIcon.vertexColor[1] == 1 and row.classIcon.vertexColor[2] == 1, "class icon at full brightness")
    assert(row.railAvatar.label.shown == false, "initials hidden")
    local point = row.classIconFrame:GetPoint()
    assert(point == "LEFT", "icon back on the left, got " .. tostring(point))
    local badgePoint, badgeRelative = row.unreadBadge.frame:GetPoint()
    assert(badgePoint == "BOTTOMRIGHT" and badgeRelative == row, "badge back in the row's right column")
  end

  -- test_expanded_rows_never_build_rail_parts
  do
    local row = RowView.bindRow(factory, newParent(factory, 260), nil, 1, person(), {})
    assert(row.railAvatar == nil and row.railGroupIcon == nil, "full list builds no rail art")
  end
end
