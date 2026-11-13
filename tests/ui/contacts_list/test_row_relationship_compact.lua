local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local FakeUI = require("tests.helpers.fake_ui")

local GUILD = { primary = "guild", ties = { "guild" }, guildName = "Stormguard" }

local function person(overrides)
  local item = {
    conversationKey = "me::WOW::jaina",
    displayName = "Jaina-Proudmoore",
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
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local compact = { compact = true }

  -- test_compact_rail_hides_the_mark_and_its_hover_frame
  local row = RowView.bindRow(factory, parent, nil, 1, person({ relationship = GUILD }), {})
  assert(row.relationshipIcon.shown == true, "full row shows the mark")
  parent:SetSize(46, 400)
  row = RowView.bindRow(factory, parent, row, 1, person({ relationship = GUILD }), compact)
  assert(row.relationshipIcon.shown == false and row.relationshipHover.shown == false, "rail hides icon and hover frame")

  -- test_expanding_restores_the_mark_only_when_a_tie_exists
  parent:SetSize(260, 400)
  row = RowView.bindRow(factory, parent, row, 1, person({ relationship = GUILD }), {})
  assert(row.relationshipIcon.shown == true and row.relationshipHover.shown == true, "the bind brings the mark back")
  parent:SetSize(46, 400)
  row = RowView.bindRow(factory, parent, row, 1, person({ relationship = GUILD }), compact)
  parent:SetSize(260, 400)
  row = RowView.bindRow(factory, parent, row, 1, person(), {})
  assert(row.relationshipIcon.shown == false and row.relationshipHover.shown == false, "no tie: still hidden after expanding")

  -- test_rail_row_created_in_compact_mode_stays_hidden
  parent:SetSize(46, 400)
  local fresh = RowView.bindRow(factory, parent, nil, 1, person({ relationship = GUILD }), compact)
  assert(fresh.relationshipIcon.shown == false and fresh.relationshipHover.shown == false, "hidden from the first bind")
end
