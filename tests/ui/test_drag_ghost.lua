local FakeUI = require("tests.helpers.fake_ui")
local DragGhost = require("WhisperMessenger.UI.MessengerWindow.DragGhost")
local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Theme = require("WhisperMessenger.UI.Theme")

local function bindRow(factory, list, item, compact)
  local parent = factory.CreateFrame("Frame", nil, list)
  parent:SetSize(compact and Theme.LAYOUT.CONTACTS_RAIL_WIDTH or 260, 400)
  return RowView.bindRow(factory, parent, nil, 1, item, { compact = compact })
end

return function()
  local factory = FakeUI.NewFactory()
  local list = factory.CreateFrame("Frame", nil, nil)
  local ghost = DragGhost.Create(factory, list)
  local sourceRow = factory.CreateFrame("Button", nil, list)
  sourceRow.item = { displayName = "Arthas#1234" }

  -- test_ghost_label_hides_battletag_numbers
  DragGhost.Show(ghost, sourceRow, list)
  assert(ghost.label.text == "Arthas", "drag ghost hides the BattleTag number, got " .. tostring(ghost.label.text))

  local jaina = { conversationKey = "me::WOW::jaina", displayName = "Jaina-Proudmoore", channel = "WOW", classTag = "MAGE", pinned = true }

  -- test_rail_ghost_looks_like_the_rail_icon
  do
    local row = bindRow(factory, list, jaina, true)
    DragGhost.Show(ghost, row, list)
    assert(ghost.label.shown == false, "no name in the rail ghost")
    assert(ghost.classIcon.texturePath == row.classIcon.texturePath, "same art as the rail row")
    assert(ghost.classIcon.vertexColor[1] < 1, "art dimmed like the rail icon")
    assert(ghost.railAvatar.label.shown == true and ghost.railAvatar.label.text == "JA", "initials on top")
    assert(ghost.railAvatar.label.parent == ghost.classIconFrame, "initials drawn on the icon")
    local point, _, _, offsetX = ghost.classIconFrame:GetPoint()
    local _, _, _, rowOffsetX = row.classIconFrame:GetPoint()
    assert(point == "CENTER" and offsetX == rowOffsetX, "icon centred like the rail row's")
  end

  -- test_rail_group_ghost_keeps_its_art_plain
  do
    local guild = { conversationKey = "guild::me", displayName = "Guild", channel = "GUILD", pinned = true }
    DragGhost.Show(ghost, bindRow(factory, list, guild, true), list)
    assert(ghost.railAvatar.label.shown == false, "no initials on a group ghost")
    assert(ghost.classIcon.vertexColor[1] == 1, "group art not dimmed")
  end

  -- test_rail_channel_ghost_shows_its_initials
  do
    local trade = { conversationKey = "channel::me-realm::trade", displayName = "Trade", channel = "CHANNEL", pinned = true }
    DragGhost.Show(ghost, bindRow(factory, list, trade, true), list)
    assert(ghost.railAvatar.label.shown == true and ghost.railAvatar.label.text == "TR", "initials on a channel ghost")
  end

  -- test_full_list_ghost_is_unchanged_after_a_rail_drag
  do
    local row = bindRow(factory, list, jaina, false)
    DragGhost.Show(ghost, row, list)
    assert(ghost.label.shown == true and ghost.label.text == "Jaina-Proudmoore", "name shown in the full-list ghost")
    assert(ghost.railAvatar.label.shown == false, "no initials in the full-list ghost")
    assert(ghost.classIcon.vertexColor[1] == 1, "art at full brightness")
    local point = ghost.classIconFrame:GetPoint()
    assert(point == "LEFT", "icon back on the left, got " .. tostring(point))
  end
end
