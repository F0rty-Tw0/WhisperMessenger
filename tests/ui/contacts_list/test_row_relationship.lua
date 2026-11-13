local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local GAP = 4 -- spec: NAME_TO_ICON_GAP
local SIZE = 14 -- spec: CONTACT_RELATIONSHIP_SIZE
local GUILD = { primary = "guild", ties = { "guild" }, guildName = "Stormguard" }
local LONG_NAME = string.rep("W", 40)

local function person(overrides)
  local item = {
    conversationKey = "me::WOW::jaina",
    displayName = "Jaina",
    lastPreview = "hello",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    classTag = "MAGE",
  }
  for key, value in pairs(overrides or {}) do
    item[key] = value
  end
  return item
end

return function()
  local factory = FakeUI.NewFactory()
  local savedFaction, savedFocus = _G.UnitFactionGroup, _G.GetMouseFocus
  ---@diagnostic disable-next-line: duplicate-set-field
  _G.UnitFactionGroup = function()
    return "Alliance", "Alliance"
  end
  local function newParent()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(260, 400)
    return parent
  end

  -- test_mark_sits_right_after_the_name
  do
    local row = RowView.bindRow(factory, newParent(), nil, 1, person({ relationship = GUILD }), {})
    local icon = row.relationshipIcon
    assert(icon ~= nil and icon.shown == true and row.relationshipHover.shown == true, "mark shown for a guildmate")
    assert(icon.texturePath == Theme.TEXTURES.relationship_guild and icon.width == SIZE, "guild art at 14 px")
    local point, relativeTo, relativePoint, x = icon:GetPoint()
    assert(point == "LEFT" and relativeTo == row.title and relativePoint == "LEFT", "anchored to the name")
    assert(x == row.title:GetStringWidth() + GAP, "one gap after the name text, got " .. tostring(x))
  end

  -- test_no_tie_creates_nothing_and_leaves_the_faction_after_the_name
  do
    local row = RowView.bindRow(factory, newParent(), nil, 1, person({ factionName = "Horde" }), {})
    assert(row.relationshipIcon == nil and row.relationshipHover == nil, "no mark frames without a tie")
    local _, _, _, factionX = row.factionIcon:GetPoint()
    assert(factionX == row.title:GetStringWidth() + GAP, "faction icon right after the name")
  end

  -- test_faction_icon_moves_after_the_mark
  do
    local row = RowView.bindRow(factory, newParent(), nil, 1, person({ factionName = "Horde", relationship = GUILD }), {})
    local _, _, _, markX = row.relationshipIcon:GetPoint()
    local _, relativeTo, _, factionX = row.factionIcon:GetPoint()
    assert(row.factionIcon.shown == true and relativeTo == row.title, "faction icon still anchored to the name")
    assert(factionX == markX + SIZE + GAP, "faction icon after the mark + one gap, got " .. tostring(factionX))
  end

  -- test_name_budget_shrinks_by_mark_plus_gap
  -- test_rebind_without_a_tie_restores_everything (Review Focus 4)
  do
    local parent = newParent()
    local row = RowView.bindRow(factory, parent, nil, 1, person({ displayName = LONG_NAME, factionName = "Horde" }), {})
    local fullWidth, fullText = row.title:GetWidth(), row.title.text
    row = RowView.bindRow(factory, parent, row, 1, person({ displayName = LONG_NAME, factionName = "Horde", relationship = GUILD }), {})
    assert(row.title:GetWidth() == fullWidth - (SIZE + GAP), "budget shrinks by mark + gap, got " .. row.title:GetWidth())
    assert(row.title:GetStringWidth() <= row.title:GetWidth(), "fitted text stays inside the shrunk budget")
    local markFrame = row.relationshipHover
    row = RowView.bindRow(factory, parent, row, 1, person({ displayName = LONG_NAME, factionName = "Horde" }), {})
    assert(row.relationshipIcon.shown == false and row.relationshipHover.shown == false, "mark and hover frame hidden")
    assert(row.relationshipHover == markFrame, "frames are reused, not rebuilt")
    assert(row.title:GetWidth() == fullWidth and row.title.text == fullText, "name budget and text restored")
    local _, _, _, factionX = row.factionIcon:GetPoint()
    assert(row.factionIcon.shown == true and factionX == row.title:GetStringWidth() + GAP, "faction icon back right after the name")
  end

  -- test_group_rows_never_show_the_mark
  do
    local group = person({ conversationKey = "guild::me", displayName = "Guild", channel = ChannelType.GUILD, relationship = GUILD })
    local row = RowView.bindRow(factory, newParent(), nil, 1, group, {})
    assert(row.relationshipIcon == nil or row.relationshipIcon.shown == false, "no mark on a group row")
  end

  -- test_clicks_on_the_mark_reach_the_row
  do
    local picked
    local row = RowView.bindRow(factory, newParent(), nil, 1, person({ relationship = GUILD }), {
      onSelect = function(item)
        picked = item
      end,
    })
    local hover = row.relationshipHover
    assert(hover.parent == row, "hover frame is a child of the row")
    assert(hover.mouseEnabled == true and hover.mouseMotionEnabled == true and hover.mouseClickEnabled == false, "motion on, clicks off")
    assert(hover.scripts.OnClick == nil and hover.scripts.OnMouseDown == nil and hover.scripts.OnMouseUp == nil, "hover frame handles no clicks")
    row.scripts.OnClick(row, "LeftButton")
    assert(picked == row.item, "row click still selects the conversation")
  end

  -- test_hovering_the_mark_keeps_the_row_highlight
  do
    local row = RowView.bindRow(factory, newParent(), nil, 1, person({ relationship = GUILD }), {})
    row.mouseOver = true
    row.scripts.OnEnter(row)
    assert(row.hoverFill.shown == true, "row highlighted on enter")
    row.mouseOver = false -- only the focus walk can keep it now
    ---@diagnostic disable-next-line: duplicate-set-field
    _G.GetMouseFocus = function()
      return row.relationshipHover
    end
    row.scripts.OnLeave(row)
    assert(row.hoverFill.shown == true, "highlight kept while the pointer is on the mark")
    ---@diagnostic disable-next-line: duplicate-set-field
    _G.GetMouseFocus = function()
      return nil
    end
    row.scripts.OnLeave(row)
    assert(row.hoverFill.shown == false, "highlight drops once the pointer leaves the row")
  end

  _G.UnitFactionGroup, _G.GetMouseFocus = savedFaction, savedFocus
end
