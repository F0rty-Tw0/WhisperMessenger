local FakeUI = require("tests.helpers.fake_ui")
local IgnoreRow = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.IgnoreRow")

local function pointTo(region, relativeTo)
  for _, point in ipairs(region.points or {}) do
    if point[2] == relativeTo then
      return point
    end
  end
  return nil
end

local function fakeTooltip()
  local state = { lines = {} }
  state.tooltip = {
    SetOwner = function(_, owner)
      state.owner = owner
      state.lines = {}
    end,
    SetText = function(_, text)
      state.lines = { { text = text } }
    end,
    AddLine = function(_, text, _r, _g, _b, wrap)
      state.lines[#state.lines + 1] = { text = text, wrap = wrap }
    end,
    Show = function()
      state.shown = true
    end,
    Hide = function()
      state.shown = false
    end,
  }
  return state
end

local function lineTexts(state)
  local out = {}
  for index, line in ipairs(state.lines) do
    out[index] = line.text
  end
  return out
end

local LONG_TEXT = "WTS boost carry cheap gold all raids and dungeons, whisper me for prices and a free run this week only"

return function()
  local factory = FakeUI.NewFactory()
  local list = factory.CreateFrame("Frame", nil, nil)
  local removedKey
  local row = IgnoreRow.Create(factory, list, function(key)
    removedKey = key
  end)
  local savedTooltip = _G.GameTooltip

  -- test_remove_button_is_centred_on_the_row
  do
    local point = row.removeButton.points[#row.removeButton.points]
    assert(point[1] == "RIGHT" and point[2] == row and point[3] == "RIGHT", "remove button centred on the row's right edge")
  end

  -- test_name_sits_above_the_row_centre
  do
    local point = pointTo(row.nameText, row)
    assert(point and point[1] == "BOTTOMLEFT" and point[3] == "LEFT" and point[5] > 0, "name line ends just above the centre")
  end

  -- test_detail_sits_below_the_row_centre
  do
    local point = pointTo(row.detailText, row)
    assert(point and point[1] == "TOPLEFT" and point[3] == "LEFT" and point[5] < 0, "count line starts just below the centre")
  end

  -- test_both_lines_stop_short_of_the_remove_button
  do
    assert(pointTo(row.nameText, row.removeButton) ~= nil, "name ends left of the button")
    assert(pointTo(row.detailText, row.removeButton) ~= nil, "count line ends left of the button")
  end

  -- test_hover_shows_name_count_reason_and_full_last_line
  do
    local state = fakeTooltip()
    _G.GameTooltip = state.tooltip
    IgnoreRow.Bind(
      row,
      { name = "Spammer-Area52", blocked = 2, reason = "gold seller", lastText = LONG_TEXT, lastChannel = "CHAT_MSG_WHISPER" },
      "spammer-area52"
    )
    row.scripts.OnEnter(row)
    local texts = lineTexts(state)
    assert(state.owner == row and state.shown, "tooltip shown on the row")
    assert(texts[1] == "Spammer-Area52", "title is the player, got " .. tostring(texts[1]))
    assert(texts[2] == "Blocked 2 this session", "count line, got " .. tostring(texts[2]))
    assert(texts[3] == "gold seller", "reason line, got " .. tostring(texts[3]))
    assert(texts[4] == "Last: [Whisper] " .. LONG_TEXT, "full last line, got " .. tostring(texts[4]))
    assert(state.lines[4].wrap == true, "last line wraps")
    row.scripts.OnLeave(row)
    assert(not state.shown, "leaving the row hides the tooltip")
  end

  -- test_hover_leaves_out_missing_reason_and_last_line
  do
    local state = fakeTooltip()
    _G.GameTooltip = state.tooltip
    IgnoreRow.Bind(row, { name = "Quiet-Area52", blocked = 0 }, "quiet-area52")
    row.scripts.OnEnter(row)
    local texts = lineTexts(state)
    assert(#texts == 2 and texts[1] == "Quiet-Area52", "title and count only, got " .. #texts .. " lines")
  end

  -- test_moving_onto_the_remove_button_and_back_swaps_tooltips
  do
    local state = fakeTooltip()
    _G.GameTooltip = state.tooltip
    row.scripts.OnEnter(row)
    -- The game sends the row's leave before the button's enter.
    row.scripts.OnLeave(row)
    row.removeButton.scripts.OnEnter(row.removeButton)
    assert(state.shown and state.owner == row.removeButton, "the remove button shows its own tooltip")
    row.scripts.OnLeave(row)
    assert(state.shown, "a second row leave leaves the button's tooltip alone")
    row.removeButton.scripts.OnLeave(row.removeButton)
    row.scripts.OnEnter(row)
    assert(state.shown and state.owner == row, "back on the row, its tooltip returns")
    row.scripts.OnLeave(row)
  end

  -- test_remove_button_still_removes_the_bound_entry
  do
    _G.GameTooltip = fakeTooltip().tooltip
    IgnoreRow.Bind(row, { name = "Quiet-Area52", blocked = 0 }, "quiet-area52")
    row.removeButton.scripts.OnClick(row.removeButton)
    assert(removedKey == "quiet-area52", "remove passes the entry key")
  end

  -- test_remove_button_tooltip_says_unblock
  do
    local state = fakeTooltip()
    _G.GameTooltip = state.tooltip
    row.removeButton.scripts.OnEnter(row.removeButton)
    assert(state.lines[1] and state.lines[1].text == "Unblock", "remove tooltip, got " .. tostring(state.lines[1] and state.lines[1].text))
    row.removeButton.scripts.OnLeave(row.removeButton)
  end

  -- test_hover_without_game_tooltip_does_nothing
  do
    _G.GameTooltip = nil
    row.scripts.OnEnter(row)
    row.scripts.OnLeave(row)
  end

  _G.GameTooltip = savedTooltip
end
