-- Characterization of every reader of the restricted-content state. Each
-- formula below is what that reader computes today, written out again from
-- the inputs alone; the real modules must give the same answer in every row.
-- Sends, the paused notice and the chat filters share one answer; the three
-- flag-only readers at the end do not yet (issue #220). A change to one of
-- these formulas is a behaviour change and has to be made here on purpose.
local TruthTable = require("tests.helpers.restriction_truth_table")

-- 67 lock scenarios with the restriction API x 6 chat locks, plus 5 chat
-- locks on a client without it, each x 3 suspended values x 4^3 flag values.
local EXPECTED_ROWS = 78144
local MAX_REPORTED = 5

local LOCK_REPORTED = { api = true, activating = true, active = true }
-- A cached Inactive overrules the API, so "inactive" leaves chat unlocked.
local CHAT_LOCKED = { info = true, cached = true, api = true, activating = true }

local function isSet(flagValue)
  return flagValue and true or false
end

local function expectedAnswers(inputs)
  local chatLocked = CHAT_LOCKED[inputs.chatLock] == true
  local cacheCompetitive = LOCK_REPORTED[inputs.encounterLock] == true
    or LOCK_REPORTED[inputs.challengeLock] == true
    or LOCK_REPORTED[inputs.pvpLock] == true
  -- Any truthy value sets a flag.
  local mythic, competitive, encounter = isSet(inputs.mythic), isSet(inputs.competitive), isSet(inputs.encounter)

  -- Sends and channel ingest: event cache or API, chat lock, two of the flags.
  local isCompetitive = cacheCompetitive or chatLocked or competitive or encounter
  local isMythic = LOCK_REPORTED[inputs.challengeLock] == true or mythic
  -- The paused banner and the icon: whatever holds sends back. The Mythic+
  -- suspend, which the mythic flag records, keeps its own banner.
  local notified = isCompetitive or isMythic
  local notice = "cleared"
  if mythic then
    notice = "kept"
  elseif notified then
    notice = "shown"
  end
  -- Chat filters: off wherever sends are held, and under the Mythic+ suspend.
  local filtersAllowed = not (isCompetitive or isMythic or inputs.suspended)

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

  -- test_whisper_filters_are_never_on_while_sends_are_held
  assert(sendsHeldWhileFiltersOn == 0, sendsHeldWhileFiltersOn .. " rows hold sends while the whisper filters stay registered")

  -- test_sends_are_never_held_without_telling_the_notice_and_icon
  assert(sendsHeldWithoutNotice == 0, sendsHeldWithoutNotice .. " rows hold sends while the notice and icon are told nothing is restricted")
end
