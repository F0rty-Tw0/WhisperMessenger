local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local RowTooltip = require("WhisperMessenger.UI.ContactsList.RowTooltip")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local FakeUI = require("tests.helpers.fake_ui")

local function texts(lines)
  local out = {}
  for index, line in ipairs(lines) do
    out[index] = line.text
  end
  return out
end

local function contains(list, value)
  for _, entry in ipairs(list) do
    if entry == value then
      return true
    end
  end
  return false
end

local function person(overrides)
  local item = {
    conversationKey = "me::WOW::jaina",
    displayName = "Jaina-Proudmoore",
    lastPreview = "see you soon",
    unreadCount = 3,
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

local function fakeTooltip()
  local state = { lines = {} }
  state.tooltip = {
    SetOwner = function(_, owner, anchor)
      state.owner, state.anchor = owner, anchor
    end,
    SetText = function(_, text, r, g, b)
      state.lines = { { text = text, r = r, g = g, b = b } }
    end,
    AddLine = function(_, text, r, g, b)
      state.lines[#state.lines + 1] = { text = text, r = r, g = g, b = b }
    end,
    Show = function()
      state.shown = true
    end,
    Hide = function()
      state.shown = false
    end,
    IsOwned = function(_, owner)
      return state.owner == owner
    end,
  }
  return state
end

return function()
  local savedColors, savedTooltip = _G.RAID_CLASS_COLORS, _G.GameTooltip
  _G.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }

  -- test_person_tooltip_lists_name_realm_zone_status_message_and_unread
  do
    local lines = RowTooltip.Lines(person(), false)
    assert(lines[1].text == "Jaina", "title is the name without realm, got " .. tostring(lines[1].text))
    assert(lines[1].color[1] == 0.25 and lines[1].color[3] == 0.92, "title uses the class colour")
    local all = texts(lines)
    assert(contains(all, "Proudmoore"), "realm line")
    assert(contains(all, "Dalaran"), "zone line")
    assert(contains(all, "Online"), "status line")
    assert(contains(all, "see you soon"), "last message line")
    assert(contains(all, "3 unread"), "unread count line")
  end

  -- test_nickname_title_keeps_the_real_name
  do
    local lines = RowTooltip.Lines(person({ nickname = "Boss" }), false)
    assert(lines[1].text == "Boss (Jaina)", "nickname plus real name, got " .. tostring(lines[1].text))
  end

  -- test_hidden_previews_leave_out_the_message
  do
    local all = texts(RowTooltip.Lines(person(), true))
    assert(not contains(all, "see you soon"), "no message text while previews are hidden")
  end

  -- test_nothing_unread_leaves_out_the_count
  do
    local all = texts(RowTooltip.Lines(person({ unreadCount = 0 }), false))
    for _, text in ipairs(all) do
      assert(not string.find(text, "unread", 1, true), "no unread line when all read")
    end
  end

  -- test_battletag_respects_hidden_numbers
  do
    local friend = person({ channel = "BN", displayName = "Friend", battleTag = "Friend#1234", classTag = nil })
    DisplayName.Configure({ hideBattleTagNumbers = false })
    assert(contains(texts(RowTooltip.Lines(friend, false)), "Friend#1234"), "BattleTag shown with numbers when allowed")
    DisplayName.Configure({ hideBattleTagNumbers = true })
    for _, text in ipairs(texts(RowTooltip.Lines(friend, false))) do
      assert(not string.find(text, "#1234", 1, true), "BattleTag number hidden, got " .. text)
    end
  end

  -- test_group_tooltip_is_label_and_last_line
  do
    local group = { channel = ChannelType.GUILD, displayName = "Guild", lastPreview = "pull at 8", unreadCount = 0 }
    local all = texts(RowTooltip.Lines(group, false))
    assert(all[1] == "Guild", "group label first, got " .. tostring(all[1]))
    assert(all[2] == "pull at 8" and #all == 2, "then only the last line")
  end

  -- test_rail_row_hover_shows_and_hides_the_tooltip_right_of_the_row
  do
    local state = fakeTooltip()
    _G.GameTooltip = state.tooltip
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(46, 400)
    local row = RowView.bindRow(factory, parent, nil, 1, person(), { compact = true })
    row.scripts.OnEnter(row)
    assert(state.shown == true and state.owner == row and state.anchor == "ANCHOR_RIGHT", "tooltip opens right of the row")
    assert(state.lines[1].text == "Jaina", "tooltip filled from the row's contact")
    row.scripts.OnLeave(row)
    assert(state.shown == false, "tooltip hides on leave")
  end

  -- test_full_list_rows_have_no_tooltip
  do
    local state = fakeTooltip()
    _G.GameTooltip = state.tooltip
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(260, 400)
    local row = RowView.bindRow(factory, parent, nil, 1, person(), {})
    row.scripts.OnEnter(row)
    assert(state.shown ~= true, "expanded rows show no tooltip")
  end

  _G.RAID_CLASS_COLORS, _G.GameTooltip = savedColors, savedTooltip
end
