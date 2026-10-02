local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local L = Theme.LAYOUT

-- In the rail each icon sits in the middle of the visible strip (where the
-- magnifier is), with the same gap to the edge or panel border the expanded
-- rows keep on their left. Live anchors (FakeUI does not resolve two-point
-- anchors, so the maths is done here): the list spans the pane from 0 to
-- paneWidth - border (Apply's HUD right inset), rows start ROW_LEFT_INSET in,
-- and the icon centre sits at the row centre plus its anchor offset.

local function railGeometry(hudStyle)
  Hud.Configure(hudStyle)
  local border = Hud.IsOn() and L.HUD_PANEL_PADDING or 0
  local paneWidth = L.CONTACTS_RAIL_WIDTH
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(paneWidth - border, 400)
  local row = RowView.bindRow(factory, parent, nil, 1, {
    conversationKey = "me::WOW::jaina",
    displayName = "Jaina",
    channel = "WOW",
    classTag = "MAGE",
    unreadCount = 0,
    lastActivityAt = 1,
  }, { compact = true })
  local rowLeft = row.points[#row.points][4]
  local rowCentre = rowLeft + (paneWidth - border - rowLeft) / 2
  local point, relativeTo, _, offsetX = row.classIconFrame:GetPoint()
  assert(point == "CENTER" and relativeTo == row, hudStyle .. ": icon centred on its row")
  Hud.Configure("off")
  local iconCentre = rowCentre + offsetX
  local half = L.CONTACT_ICON_SIZE / 2
  return {
    paneCentre = paneWidth / 2,
    iconCentre = iconCentre,
    leftGap = iconCentre - half - border,
    rightGap = (paneWidth - border) - (iconCentre + half),
    border = border,
  }
end

return function()
  -- Expanded rows: icon left edge at the row inset + contact padding.
  local expandedIconLeft = L.CONTACT_ROW_LEFT_INSET + L.CONTACT_PADDING

  for _, style in ipairs({ "off", "classic" }) do
    local g = railGeometry(style)

    -- test_icon_lines_up_with_the_magnifier
    assert(g.iconCentre == g.paneCentre, style .. ": icon centre " .. g.iconCentre .. " vs pane centre " .. g.paneCentre)

    -- test_equal_gaps_matching_the_expanded_rows
    assert(g.leftGap == g.rightGap, style .. ": gaps " .. g.leftGap .. "/" .. g.rightGap)
    assert(g.leftGap == expandedIconLeft - g.border, style .. ": rail gap " .. g.leftGap .. " vs expanded " .. (expandedIconLeft - g.border))
  end

  -- test_accent_bar_stays_on_the_left_edge
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(L.CONTACTS_RAIL_WIDTH, 400)
  local row = RowView.bindRow(factory, parent, nil, 1, { conversationKey = "k", displayName = "A", channel = "WOW" }, { compact = true })
  assert(row.accentBar.points[1][1] == "TOPLEFT" and row.accentBar.points[1][2] == row, "accent bar on the row's left edge")
end
