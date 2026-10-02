-- Rows are keyed by message identity, not index: when the message cap drops
-- the oldest message, every remaining row must keep its measured height.

local TranscriptRows = require("WhisperMessenger.UI.ConversationPane.TranscriptRows")

local function msg(id, sentAt)
  return { id = id, kind = "user", direction = "in", text = id, sentAt = sentAt, playerName = "A-R" }
end

return function()
  -- test_cap_shift_keeps_measured_height_of_unchanged_message
  do
    local m1, m2, m3, m4 = msg("1", 1), msg("2", 2), msg("3", 3), msg("4", 4)
    local transcript = {}
    local state = TranscriptRows.Prepare(transcript, { m1, m2, m3 }, 400, nil)
    state.rows[3].height = 77
    local shifted = TranscriptRows.Prepare(transcript, { m2, m3, m4 }, 400, nil)
    assert(shifted.rows[1].message == m2, "row 1 must hold m2 after the cap shift")
    assert(shifted.rows[2].message == m3, "row 2 must hold m3 after the cap shift")
    assert(shifted.rows[2].height == 77, "unchanged message keeps its measured height, got " .. tostring(shifted.rows[2].height))
  end

  -- test_repeat_count_change_marks_transcript_changed
  do
    local m1, m2 = msg("1", 1), msg("2", 2)
    local transcript = {}
    TranscriptRows.Prepare(transcript, { m1, m2 }, 400, nil)
    m2.repeatCount = 2
    local _, changed = TranscriptRows.Prepare(transcript, { m1, m2 }, 400, nil)
    assert(changed == true, "repeatCount change must mark the transcript changed")
  end

  -- test_dropped_message_leaves_the_row_index
  do
    local m1, m2, m3 = msg("1", 1), msg("2", 2), msg("3", 3)
    local transcript = {}
    TranscriptRows.Prepare(transcript, { m1, m2 }, 400, nil)
    local state = TranscriptRows.Prepare(transcript, { m2, m3 }, 400, nil)
    assert(state.rowByMessage[m1] == nil, "a message no longer shown must not keep its row")
    assert(state.rowByMessage[m3] == state.rows[2], "a shown message must map to its row")
    assert(state.rows[1] ~= state.rows[2], "rows must not be shared between messages")
  end
end
