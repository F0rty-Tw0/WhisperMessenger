require("tests.helpers.fake_ui")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")
local SenderLevelBackfill = require("WhisperMessenger.Model.SenderLevelBackfill")

local TRADE_KEY = "me::CHANNEL::trade"

local function fire(event, ...)
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, event, ...)
end

-- The player's realm is Kazzak: same-realm names lose their realm.
local function sameRealmAmbiguate(name, _context)
  return (string.gsub(name, "%-Kazzak$", ""))
end

local function whoRow(level)
  return { fullName = "Ishtarra", level = level, area = "Silvermoon City" }
end

-- A runtime whose store holds one Trade chat with one line from Ishtarra.
local function makeRuntime(results)
  local line = { direction = "in", kind = "user", playerName = "Ishtarra-Kazzak" }
  local runtime = {
    localProfileId = "me",
    store = { conversations = { [TRADE_KEY] = { channel = "CHANNEL", messages = { line } } } },
    refreshed = {},
  }
  runtime.friendListApi = {
    GetNumWhoResults = function()
      return #results
    end,
    GetWhoInfo = function(i)
      return results[i]
    end,
  }
  runtime.scheduleIncomingRefresh = function(key)
    runtime.refreshed[#runtime.refreshed + 1] = key
  end
  return runtime, line
end

return function()
  local savedAmbiguate = _G.Ambiguate
  local realOnWhoListUpdate = WhoLookup.OnWhoListUpdate
  rawset(_G, "Ambiguate", sameRealmAmbiguate)
  WhoLookup.OnWhoListUpdate = function() end
  local function reset(results)
    SeenLevelEvents._reset()
    SeenLevel._reset()
    local runtime, line = makeRuntime(results)
    SeenLevelEvents.Init(runtime)
    return runtime, line
  end

  -- test_who_reply_fills_stored_trade_line
  do
    local runtime, line = reset({ whoRow(90) })
    fire("WHO_LIST_UPDATE")
    assert(line.senderLevel == 90, "expected level 90, got " .. tostring(line.senderLevel))
    assert(#runtime.refreshed == 1 and runtime.refreshed[1] == TRADE_KEY, "expected one refresh for the Trade chat")
  end

  -- test_who_system_line_fills_stored_trade_line
  do
    local _, line = reset({ whoRow(90) })
    fire("CHAT_MSG_SYSTEM", "[Ishtarra]: Level 90 Dracthyr Mage - Silvermoon City")
    assert(line.senderLevel == 90, "expected level 90 from the system line, got " .. tostring(line.senderLevel))
  end

  -- test_unrelated_system_line_changes_nothing
  -- Any system line inside the who window reaches recordWho; only /who rows count.
  do
    local runtime, line = reset({ whoRow(90) })
    fire("CHAT_MSG_SYSTEM", "Ishtarra has come online.")
    assert(line.senderLevel == nil, "an unrelated system line must not fill levels")
    assert(#runtime.refreshed == 0, "an unrelated system line must not refresh chats")
  end

  -- test_many_rows_walk_store_once
  do
    local realApply = SenderLevelBackfill.Apply
    local walks = 0
    SenderLevelBackfill.Apply = function(...)
      walks = walks + 1
      return realApply(...)
    end
    reset({ whoRow(90), { fullName = "Nergrom", level = 20, area = "Orgrimmar" }, { fullName = "Jaina", level = 35, area = "Dalaran" } })
    fire("WHO_LIST_UPDATE")
    SenderLevelBackfill.Apply = realApply
    assert(walks == 1, "a reply should walk the store once, walked " .. walks)
  end

  -- test_two_rows_same_name_keep_higher
  do
    local _, line = reset({ whoRow(90), whoRow(80) })
    fire("WHO_LIST_UPDATE")
    assert(line.senderLevel == 90, "the higher level should win, got " .. tostring(line.senderLevel))
  end

  -- test_blocked_capture_changes_nothing
  do
    local runtime, line = reset({ whoRow(90) })
    runtime.isCompetitiveContent = function()
      return true
    end
    fire("WHO_LIST_UPDATE")
    assert(line.senderLevel == nil, "nothing should change while capture is blocked")
  end

  -- test_zero_level_row_changes_nothing
  do
    local _, line = reset({ whoRow(0) })
    fire("WHO_LIST_UPDATE")
    assert(line.senderLevel == nil, "a zero level must be skipped")
  end

  -- test_string_level_row_changes_nothing
  do
    local _, line = reset({ whoRow("90") })
    fire("WHO_LIST_UPDATE")
    assert(line.senderLevel == nil, "a non-number level must be skipped")
  end

  rawset(_G, "Ambiguate", savedAmbiguate)
  WhoLookup.OnWhoListUpdate = realOnWhoListUpdate
  SeenLevelEvents._reset()
  SeenLevel._reset()
end
