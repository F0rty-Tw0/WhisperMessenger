-- Characterization of every reader of the restricted-content state. Each
-- formula below is what that reader computes today, written out again from
-- the inputs alone; the real modules must give the same answer in every row.
-- The readers do not agree with each other (issue #220): a change to one of
-- these formulas is a behaviour change and has to be made here on purpose.
local TruthTable = require("tests.helpers.restriction_truth_table")

local EXPECTED_ROWS = 21951
local MAX_REPORTED = 5

local LOCK_REPORTED = { api = true, activating = true, active = true }

local function expectedAnswers(inputs)
  local chatLocked = inputs.chatLock ~= "off"
  local cacheCompetitive = LOCK_REPORTED[inputs.encounterLock] == true
    or LOCK_REPORTED[inputs.challengeLock] == true
    or LOCK_REPORTED[inputs.pvpLock] == true
  local mythic, competitive, encounter = inputs.mythic == true, inputs.competitive == true, inputs.encounter == true

  -- Sends and channel ingest: event cache or API, chat lock, two of the flags.
  local isCompetitive = cacheCompetitive or chatLocked or competitive or encounter
  local isMythic = LOCK_REPORTED[inputs.challengeLock] == true or mythic
  -- The paused banner and the icon: the three flags and the chat lock, never the cache.
  local notified = competitive or mythic or encounter or chatLocked
  local notice = "cleared"
  if mythic then
    notice = "kept"
  elseif notified then
    notice = "shown"
  end
  -- Chat filters: the flags, the Mythic+ suspend and the chat lock, never the cache.
  local filtersAllowed = not (competitive or mythic or encounter or inputs.suspended or chatLocked)

  return {
    isCompetitive,
    isMythic,
    chatLocked,
    isMythic or isCompetitive,
    isMythic or isCompetitive,
    notified,
    notice,
    filtersAllowed,
    filtersAllowed,
    -- Flag only: the window's availability requests, the event frame, the catcher.
    mythic,
    not mythic,
    mythic,
  }
end

return function()
  local mismatches = {}
  local mismatchCount = 0
  local sendsHeldWhileFiltersOn = 0
  local sendsHeldWithoutNotice = 0

  local rows = TruthTable.Run(function(label, inputs, answers)
    local expected = expectedAnswers(inputs)
    for index, reader in ipairs(TruthTable.READERS) do
      if answers[index] ~= expected[index] then
        mismatchCount = mismatchCount + 1
        if #mismatches < MAX_REPORTED then
          mismatches[#mismatches + 1] =
            string.format("%s answered %s, expected %s at %s", reader, tostring(answers[index]), tostring(expected[index]), label)
        end
      end
    end
    if answers[1] == true and answers[8] == true then
      sendsHeldWhileFiltersOn = sendsHeldWhileFiltersOn + 1
    end
    if answers[1] == true and answers[6] == false then
      sendsHeldWithoutNotice = sendsHeldWithoutNotice + 1
    end
  end)

  -- test_every_reader_answers_by_its_own_formula
  assert(mismatchCount == 0, mismatchCount .. " answers changed:\n" .. table.concat(mismatches, "\n"))

  -- test_table_visits_every_combination
  assert(rows == EXPECTED_ROWS, "expected " .. EXPECTED_ROWS .. " rows, got " .. rows)

  -- test_cache_only_restriction_holds_sends_but_keeps_whisper_filters
  assert(sendsHeldWhileFiltersOn > 0, "the cache-only rows must be in the table")

  -- test_cache_only_restriction_holds_sends_without_the_paused_notice
  assert(sendsHeldWithoutNotice > 0, "the cache-only rows must be in the table")
end
