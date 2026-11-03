local TranscriptRows = require("WhisperMessenger.UI.ConversationPane.TranscriptRows")
local Geometry = require("WhisperMessenger.UI.ConversationPane.TranscriptRowGeometry")

local PAD = TranscriptRows.CONTENT_PAD

local function makeRows(count, height)
  local rows = {}
  for index = 1, count do
    rows[index] = { index = index, height = height, message = { id = index } }
  end
  Geometry.RecomputeOffsets(rows, 1)
  return rows
end

return function()
  -- test_recompute_offsets_stacks_rows_below_the_top_pad
  do
    local rows = makeRows(3, 20)
    assert(rows[1].offset == PAD, "first row starts at the pad")
    assert(rows[3].offset == PAD + 40, "third row after two rows, got " .. rows[3].offset)
    assert(Geometry.TotalHeight(rows) == PAD + 60 + PAD, "total includes both pads")
  end

  -- test_total_height_of_no_rows_is_zero
  assert(Geometry.TotalHeight({}) == 0, "empty transcript has no height")

  -- test_range_for_offset_adds_overscan_rows_and_clamps
  do
    local rows = makeRows(20, 20)
    local first, last = Geometry.RangeForOffset(rows, rows[10].offset, 40)
    assert(first == 8, "two overscan rows above, got " .. tostring(first))
    assert(last == 14, "two overscan rows below, got " .. tostring(last))
    local topFirst = Geometry.RangeForOffset(rows, 0, 40)
    assert(topFirst == 1, "clamped at the first row")
  end

  -- test_anchor_follows_its_message_after_rows_above_grow
  do
    local rows = makeRows(5, 20)
    local message, delta, index = Geometry.CaptureAnchor(rows, rows[3].offset + 5)
    assert(message == rows[3].message and delta == 5 and index == 3, "anchor on row 3, 5px in")
    rows[1].height = 50
    Geometry.RecomputeOffsets(rows, 1)
    assert(Geometry.AnchoredOffset(rows, message, delta, index) == rows[3].offset + 5, "offset follows the message")
  end

  -- test_anchored_offset_of_a_dropped_message_is_nil
  assert(Geometry.AnchoredOffset(makeRows(2, 20), { id = 99 }, 0, 1) == nil, "unknown message has no offset")
end
