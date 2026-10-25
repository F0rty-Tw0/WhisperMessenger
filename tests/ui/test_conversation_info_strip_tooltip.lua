local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

local contact = { displayName = "Jaina", conversationKey = "wow::WOW::jaina" }
local conv = { messages = {} }
local ITEM_LINE = "Craft Alert: |cffa335ee|Hitem:12345::|h[Signet]|h|r"

-- A GameTooltip that records what was shown; `state.lines` resets on SetOwner,
-- `state.owner` clears on Hide. `withIsOwned = false` models a tooltip without IsOwned.
local function installTooltip(withIsOwned)
  local state = { visible = false, lines = {} }
  local saved = rawget(_G, "GameTooltip")
  _G.GameTooltip = {
    SetOwner = function(_self, owner, anchor)
      state.owner, state.anchor, state.lines, state.link = owner, anchor, {}, nil
    end,
    AddLine = function(_self, text, _r, _g, _b, wrap)
      state.lines[#state.lines + 1] = text
      state.wrap = wrap
    end,
    SetHyperlink = function(_self, link)
      state.link = link
    end,
    Show = function()
      state.visible = true
    end,
    Hide = function()
      state.visible = false
      state.owner = nil
    end,
    SetMinimumWidth = function(_self, width)
      state.minWidth = width
    end,
  }
  if withIsOwned ~= false then
    _G.GameTooltip.IsOwned = function(_self, frame)
      return state.owner == frame
    end
  end
  local function restore()
    _G.GameTooltip = saved
  end
  return state, restore
end

-- A strip showing `lines` with `tooltips`; returns the strip and its first row frame.
local function newStrip(lines, tooltips)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, contact, conv, {
    getContactInfoLines = function()
      return lines, tooltips
    end,
  })
  return pane.infoStrip, pane.infoStrip.rowFrames[1]
end

local function run(body, withIsOwned)
  local state, restore = installTooltip(withIsOwned)
  local ok, err = pcall(body, state)
  restore()
  assert(ok, err)
end

return function()
  -- test_hovering_a_row_shows_its_tooltip_lines
  run(function(state)
    local _, row = newStrip({ "Craft Alert: Belt" }, { { "Matched: Belt", "Tailoring" } })
    assert(row.mouseEnabled == true, "the row takes the mouse")
    row.scripts.OnEnter(row)
    assert(state.owner == row, "anchored to the row")
    assert(state.visible == true, "shown")
    assert(#state.lines == 2 and state.lines[1] == "Matched: Belt" and state.lines[2] == "Tailoring", "both lines added")
    assert(state.wrap == true, "lines wrap")
  end)

  -- test_the_row_tooltip_is_wider_than_the_game_default
  run(function(state)
    local _, row = newStrip({ "Craft Alert: Belt" }, { { "Matched: Belt" } })
    row.scripts.OnEnter(row)
    assert(type(state.minWidth) == "number" and state.minWidth >= 400, "minimum width set, got " .. tostring(state.minWidth))
  end)

  -- test_leaving_the_row_gives_the_tooltip_its_default_width_back
  run(function(state)
    local _, row = newStrip({ "Craft Alert: Belt" }, { { "Matched: Belt" } })
    row.scripts.OnEnter(row)
    row.scripts.OnLeave(row)
    assert(state.minWidth == 0, "minimum width reset, got " .. tostring(state.minWidth))
  end)

  -- test_a_link_in_the_row_keeps_the_game_tooltip_width
  run(function(state)
    local _, row = newStrip({ ITEM_LINE }, { { "Matched: Signet" } })
    row.scripts.OnEnter(row)
    row.scripts.OnHyperlinkEnter(row, "item:12345::", "[Signet]")
    assert(state.minWidth == 0, "item tooltip at the game's width, got " .. tostring(state.minWidth))
  end)

  -- test_leaving_the_row_hides_the_tooltip
  run(function(state)
    local _, row = newStrip({ "Craft Alert: Belt" }, { { "Matched: Belt" } })
    row.scripts.OnEnter(row)
    row.scripts.OnLeave(row)
    assert(state.visible == false, "hidden on leave")
  end)

  -- test_a_row_without_tooltip_lines_shows_nothing
  run(function(state)
    local _, row = newStrip({ "Craft Alert: Belt" }, {})
    row.scripts.OnEnter(row)
    assert(state.owner == nil and state.visible == false, "no tooltip")
  end)

  -- test_each_row_shows_its_own_tooltip
  run(function(state)
    local strip = newStrip({ "A", "B" }, { nil, { "B tip" } })
    local first, second = strip.rowFrames[1], strip.rowFrames[2]
    first.scripts.OnEnter(first)
    assert(state.visible == false, "A has no tooltip")
    second.scripts.OnEnter(second)
    assert(state.owner == second and state.lines[1] == "B tip", "B shows its own")
  end)

  -- test_a_link_in_the_row_shows_the_item_over_the_row_tooltip
  run(function(state)
    local _, row = newStrip({ ITEM_LINE }, { { "Matched: Signet" } })
    row.scripts.OnEnter(row)
    row.scripts.OnHyperlinkEnter(row, "item:12345::", "[Signet]")
    assert(state.link == "item:12345::" and state.visible == true, "item tooltip shown")
    assert(#state.lines == 0, "row lines replaced by the item")
  end)

  -- test_moving_off_the_link_onto_the_row_shows_the_row_tooltip_again
  run(function(state)
    local _, row = newStrip({ ITEM_LINE }, { { "Matched: Signet" } })
    row.scripts.OnEnter(row)
    row.scripts.OnHyperlinkEnter(row, "item:12345::", "[Signet]")
    row.scripts.OnHyperlinkLeave(row)
    assert(state.visible == true and state.owner == row, "row tooltip back")
    assert(state.lines[1] == "Matched: Signet" and state.link == nil, "with the row lines")
  end)

  -- test_leaving_the_row_from_the_link_leaves_no_tooltip
  run(function(state)
    local _, row = newStrip({ ITEM_LINE }, { { "Matched: Signet" } })
    row.scripts.OnEnter(row)
    row.scripts.OnHyperlinkEnter(row, "item:12345::", "[Signet]")
    row.scripts.OnLeave(row)
    row.scripts.OnHyperlinkLeave(row)
    assert(state.visible == false, "nothing shown once the cursor is off the row")
  end)

  -- test_new_lines_replace_the_tooltip_a_row_shows
  run(function(state)
    local strip, row = newStrip({ "A" }, { { "old" } })
    strip.setLines({ "A" }, { { "new" } })
    row.scripts.OnEnter(row)
    assert(state.lines[1] == "new", "the latest tooltip lines")
  end)

  -- test_lines_without_tooltips_clear_the_row_tooltip
  run(function(state)
    local strip, row = newStrip({ "A" }, { { "old" } })
    strip.setLines({ "A" })
    row.scripts.OnEnter(row)
    assert(state.owner == nil and state.visible == false, "no tooltip left on the row")
  end)

  -- test_leaving_a_row_keeps_a_tooltip_another_frame_owns
  run(function(state)
    local _, row = newStrip({ "Craft Alert: Belt" }, { { "Matched: Belt" } })
    local other = {}
    _G.GameTooltip:SetOwner(other, "ANCHOR_RIGHT")
    _G.GameTooltip:Show()
    row.scripts.OnLeave(row)
    assert(state.visible == true and state.owner == other, "the other frame's tooltip stays")
  end)

  -- test_leaving_a_row_hides_its_tooltip_when_the_tooltip_has_no_is_owned
  run(function(state)
    local _, row = newStrip({ "Craft Alert: Belt" }, { { "Matched: Belt" } })
    row.scripts.OnEnter(row)
    row.scripts.OnLeave(row)
    assert(state.visible == false, "falls back to hiding")
  end, false)

  -- test_changed_tooltip_lines_refresh_the_tooltip_while_hovered
  run(function(state)
    local strip, row = newStrip({ "A" }, { { "old" } })
    row.scripts.OnEnter(row)
    strip.setLines({ "A" }, { { "new" } })
    assert(state.visible == true and state.owner == row, "still shown on the row")
    assert(#state.lines == 1 and state.lines[1] == "new", "with the new lines")
  end)

  -- test_unchanged_tooltip_lines_leave_a_link_tooltip_alone
  run(function(state)
    local strip, row = newStrip({ ITEM_LINE }, { { "Matched: Signet" } })
    row.scripts.OnEnter(row)
    row.scripts.OnHyperlinkEnter(row, "item:12345::", "[Signet]")
    strip.setLines({ ITEM_LINE }, { { "Matched: Signet" } })
    assert(state.link == "item:12345::" and #state.lines == 0, "the item tooltip is not replaced")
  end)

  -- test_removed_tooltip_lines_hide_the_tooltip_while_hovered
  run(function(state)
    local strip, row = newStrip({ "A" }, { { "old" } })
    row.scripts.OnEnter(row)
    strip.setLines({ "A" })
    assert(state.visible == false, "nothing left to show")
  end)

  -- test_a_row_hidden_while_hovered_hides_its_tooltip
  run(function(state)
    local strip = newStrip({ "A", "B" }, { { "a tip" }, { "b tip" } })
    local second = strip.rowFrames[2]
    second.scripts.OnEnter(second)
    strip.setLines({ "A" }, { { "a tip" } })
    assert(state.visible == false, "the hidden row's tooltip is gone")
  end)

  -- test_changed_lines_do_not_touch_a_tooltip_another_frame_owns
  run(function(state)
    local strip = newStrip({ "A" }, { { "old" } })
    local other = {}
    _G.GameTooltip:SetOwner(other, "ANCHOR_RIGHT")
    _G.GameTooltip:Show()
    strip.setLines({ "A" }, { { "new" } })
    assert(state.visible == true and state.owner == other and #state.lines == 0, "left alone")
  end)

  -- test_changed_lines_do_not_swap_the_tooltip_while_a_link_is_hovered
  run(function(state)
    local strip, row = newStrip({ ITEM_LINE }, { { "old" } })
    row.scripts.OnEnter(row)
    row.scripts.OnHyperlinkEnter(row, "item:12345::", "[Signet]")
    strip.setLines({ ITEM_LINE }, { { "new" } })
    assert(state.link == "item:12345::" and #state.lines == 0, "the item tooltip stays under the cursor")
  end)

  -- test_leaving_the_link_lets_changed_lines_refresh_the_tooltip_again
  run(function(state)
    local strip, row = newStrip({ ITEM_LINE }, { { "old" } })
    row.scripts.OnEnter(row)
    row.scripts.OnHyperlinkEnter(row, "item:12345::", "[Signet]")
    row.scripts.OnHyperlinkLeave(row)
    strip.setLines({ ITEM_LINE }, { { "new" } })
    assert(state.owner == row and state.lines[1] == "new", "the row tooltip follows the new lines")
  end)

  -- test_a_row_hidden_while_a_link_is_hovered_hides_the_link_tooltip
  run(function(state)
    local strip, row = newStrip({ ITEM_LINE }, { { "old" } })
    row.scripts.OnEnter(row)
    row.scripts.OnHyperlinkEnter(row, "item:12345::", "[Signet]")
    strip.setLines({})
    assert(state.visible == false, "no tooltip is left for a row that went away")
  end)
end
