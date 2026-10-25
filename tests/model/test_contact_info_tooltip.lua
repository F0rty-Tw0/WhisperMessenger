local ContactInfo = require("WhisperMessenger.Model.ContactInfo")
local TextLimits = require("WhisperMessenger.Util.TextLimits")

local JAINA = { conversationKey = "wow::WOW::jaina-proudmoore" }

local function makeRuntime()
  local runtime = {
    store = { conversations = { [JAINA.conversationKey] = { channel = "WOW", displayName = "Jaina-Proudmoore" } } },
  }
  runtime.contactInfo = ContactInfo.New()
  return runtime
end

local function set(runtime, sourceKey, text, tooltipLines)
  return ContactInfo.Set(runtime.contactInfo, sourceKey, "Jaina-Proudmoore", text, runtime, tooltipLines)
end

return function()
  -- test_tooltip_lines_come_back_with_their_line
  do
    local runtime = makeRuntime()
    assert(set(runtime, "ca", "Craft Alert: Belt", { "Matched: Belt", "|cff00ff00Tailoring|r" }) == true)
    local lines, tooltips = ContactInfo.LinesFor(runtime, JAINA)
    assert(lines[1] == "Craft Alert: Belt", "the line")
    assert(type(tooltips) == "table" and type(tooltips[1]) == "table", "a tooltip for the line")
    assert(#tooltips[1] == 2 and tooltips[1][1] == "Matched: Belt" and tooltips[1][2] == "|cff00ff00Tailoring|r", "both tooltip lines")
  end

  -- test_invalid_tooltip_lines_return_false_and_change_nothing
  do
    local tooMany = {}
    for index = 1, ContactInfo.MAX_TOOLTIP_LINES + 1 do
      tooMany[index] = "line " .. index
    end
    local bad = {
      "not a table",
      5,
      {},
      { "ok", 5 },
      { "ok", "" },
      { "ok", nil, "gap" },
      { "ok", extra = "x" },
      { [2] = "no first" },
      tooMany,
    }
    for index, value in ipairs(bad) do
      local runtime = makeRuntime()
      assert(set(runtime, "ca", "old", { "old tip" }) == true)
      assert(set(runtime, "ca", "new", value) == false, "bad tooltip shape " .. index)
      local lines, tooltips = ContactInfo.LinesFor(runtime, JAINA)
      assert(lines[1] == "old" and tooltips[1][1] == "old tip", "nothing changed for shape " .. index)
    end
  end

  -- test_a_huge_tooltip_table_is_refused
  do
    local huge = {}
    for index = 1, 5000 do
      huge[index] = "line " .. index
    end
    local runtime = makeRuntime()
    assert(set(runtime, "ca", "text", huge) == false, "5000 lines refused")
    assert(ContactInfo.LinesFor(runtime, JAINA)[1] == nil, "nothing stored")
  end

  -- test_the_most_tooltip_lines_are_accepted
  do
    local runtime = makeRuntime()
    local most = {}
    for index = 1, ContactInfo.MAX_TOOLTIP_LINES do
      most[index] = "line " .. index
    end
    assert(set(runtime, "ca", "x", most) == true, "the cap itself is allowed")
  end

  -- test_changing_the_callers_table_later_changes_nothing
  do
    local runtime = makeRuntime()
    local tip = { "Matched: Belt" }
    set(runtime, "ca", "x", tip)
    tip[1] = "changed"
    tip[2] = "added"
    local _, tooltips = ContactInfo.LinesFor(runtime, JAINA)
    assert(#tooltips[1] == 1 and tooltips[1][1] == "Matched: Belt", "the stored copy is untouched")
  end

  -- test_removing_the_line_removes_its_tooltip
  do
    local runtime = makeRuntime()
    set(runtime, "ca", "x", { "tip" })
    assert(set(runtime, "ca", nil) == true)
    local lines, tooltips = ContactInfo.LinesFor(runtime, JAINA)
    assert(#lines == 0 and next(tooltips) == nil, "line and tooltip gone")
    assert(next(runtime.contactInfo) == nil, "nothing left in the state")
  end

  -- test_text_without_tooltip_lines_clears_the_old_tooltip
  do
    local runtime = makeRuntime()
    set(runtime, "ca", "x", { "tip" })
    assert(set(runtime, "ca", "y") == true)
    local lines, tooltips = ContactInfo.LinesFor(runtime, JAINA)
    assert(lines[1] == "y" and tooltips[1] == nil, "the new text has no tooltip")
  end

  -- test_each_source_keeps_its_own_tooltip
  do
    local runtime = makeRuntime()
    set(runtime, "b", "B text", { "B tip" })
    set(runtime, "a", "A text")
    set(runtime, "c", "C text", { "C tip" })
    local lines, tooltips = ContactInfo.LinesFor(runtime, JAINA)
    assert(lines[1] == "A text" and tooltips[1] == nil, "A has none")
    assert(lines[2] == "B text" and tooltips[2][1] == "B tip", "B keeps its tooltip")
    assert(lines[3] == "C text" and tooltips[3][1] == "C tip", "C keeps its tooltip")
  end

  -- test_a_huge_tooltip_line_is_cut_to_the_chat_limit
  do
    local runtime = makeRuntime()
    local huge = string.rep("x", 100000)
    assert(set(runtime, "ca", "x", { "short", huge }) == true)
    local _, tooltips = ContactInfo.LinesFor(runtime, JAINA)
    assert(tooltips[1][1] == "short", "a short line is untouched")
    assert(#tooltips[1][2] == TextLimits.MESSAGE_MAX_BYTES, "cut to the limit, got " .. #tooltips[1][2])
  end
end
