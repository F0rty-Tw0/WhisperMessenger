local FakeChatLines = require("tests.helpers.fake_chat_lines")
local ReplayRuntime = require("tests.helpers.lockdown_replay_runtime")
local LockdownReplay = require("WhisperMessenger.Core.Bootstrap.LockdownReplay")
local Store = require("WhisperMessenger.Model.ConversationStore")

local KEY = "wow::WOW::arthas-area52"

local function readable(text)
  return { text = text or "held hello", name = "Arthas-Area52", guid = "Player-1-ABC" }
end

local function holdOne(lines)
  local restore = FakeChatLines.Install(lines or { [7] = readable() })
  local runtime = ReplayRuntime.New()
  ReplayRuntime.Hold(runtime, "CHAT_MSG_WHISPER", 7)
  return runtime, restore
end

return function()
  -- test_kick_does_nothing_when_nothing_pending

  do
    local restore = FakeChatLines.Install({})
    LockdownReplay.Kick(ReplayRuntime.New())
    assert(#FakeChatLines.ticks == 0, "nothing held must start no ticker")
    restore()
  end

  -- test_kick_tolerates_bare_runtime

  do
    local restore = FakeChatLines.Install({})
    LockdownReplay.Kick({})
    LockdownReplay.Kick(nil)
    LockdownReplay.Tick({})
    LockdownReplay.Tick(nil)
    assert(LockdownReplay.IsReady(nil) == false and LockdownReplay.IsPending({}) == false, "bare runtimes are never ready or pending")
    assert(#FakeChatLines.ticks == 0, "bare runtimes must start no ticker")
    restore()
  end

  -- test_kick_while_locked_starts_no_ticker

  do
    local runtime, restore = holdOne()
    FakeChatLines.locked = true
    LockdownReplay.Kick(runtime)
    assert(#FakeChatLines.ticks == 0, "a locked chat must start no ticker")
    restore()
  end

  -- test_tick_while_locked_stops_ticker_and_files_after_lift

  do
    local runtime, restore = holdOne()
    LockdownReplay.Kick(runtime)
    assert(#FakeChatLines.ticks == 1, "setup: kick must start a ticker")
    FakeChatLines.locked = true
    FakeChatLines.Fire()
    assert(#FakeChatLines.ticks == 0, "a tick under lock must cancel the ticker")
    assert(runtime.lockdownReplay.ticker == nil, "a cancelled ticker must be forgotten")
    FakeChatLines.locked = false
    LockdownReplay.Kick(runtime)
    FakeChatLines.Fire()
    assert(runtime.lockdownReplay.lastSummary.filed == 1, "the held line must still file after the lock lifts")
    restore()
  end

  -- test_tick_while_locked_spends_no_try_on_waiting_line

  do
    local runtime, restore = holdOne({ [7] = { text = FakeChatLines.SECRET, name = "Arthas-Area52" } })
    LockdownReplay.Kick(runtime)
    FakeChatLines.Fire()
    assert(runtime.lockdownReplay.drained[1].tries == 1, "setup: an unreadable line must spend one try")
    FakeChatLines.locked = true
    FakeChatLines.Fire()
    assert(runtime.lockdownReplay.drained[1].tries == 1, "a tick under lock must spend no try")
    restore()
  end

  -- test_tick_while_wm_suspended_stops_ticker

  do
    local runtime, restore = holdOne()
    LockdownReplay.Kick(runtime)
    local savedSuspended = rawget(_G, "_wmSuspended")
    rawset(_G, "_wmSuspended", true)
    FakeChatLines.Fire()
    rawset(_G, "_wmSuspended", savedSuspended)
    assert(#FakeChatLines.ticks == 0, "a tick while suspended must cancel the ticker")
    assert(LockdownReplay.IsPending(runtime), "the held line must stay pending")
    restore()
  end

  -- test_character_whisper_filed_at_held_time_before_later_messages

  do
    local runtime, restore = holdOne()
    Store.AppendIncoming(runtime.store, KEY, {
      id = "live",
      direction = "in",
      kind = "user",
      text = "live",
      sentAt = 600,
      lineID = 50,
      playerName = "Arthas-Area52",
    }, false)
    LockdownReplay.Kick(runtime)
    FakeChatLines.Fire()
    local messages = runtime.store.conversations[KEY].messages
    assert(messages[1].text == "held hello" and messages[1].sentAt == 500, "held whisper must file at its held time first")
    assert(runtime.lockdownReplay.lastSummary.filed == 1, "one whisper filed, got " .. tostring(runtime.lockdownReplay.lastSummary.filed))
    assert(#FakeChatLines.ticks == 0 and runtime.lockdownReplay.ticker == nil, "a finished batch must stop its ticker")
    restore()
  end

  -- test_over_cap_lost_counted_in_summary

  do
    local lines = {}
    for lineID = 1, 200 do
      lines[lineID] = readable("held " .. lineID)
    end
    local restore = FakeChatLines.Install(lines)
    local runtime = ReplayRuntime.New()
    for lineID = 1, 201 do
      ReplayRuntime.Hold(runtime, "CHAT_MSG_WHISPER", lineID)
    end
    LockdownReplay.Kick(runtime)
    ReplayRuntime.FireUntilDone(runtime)
    local summary = runtime.lockdownReplay.lastSummary
    assert(summary.lost == 1, "the whisper past the cap must count as lost, got " .. tostring(summary.lost))
    assert(summary.filed == 200, "every held whisper must file, got " .. tostring(summary.filed))
    restore()
  end

  -- test_second_batch_after_finish_starts_new_ticker

  do
    local runtime, restore = holdOne({ [7] = readable(), [8] = readable("second") })
    LockdownReplay.Kick(runtime)
    FakeChatLines.Fire()
    assert(runtime.lockdownReplay.lastSummary ~= nil, "setup: the first batch must finish")
    ReplayRuntime.Hold(runtime, "CHAT_MSG_WHISPER", 8)
    LockdownReplay.Kick(runtime)
    assert(#FakeChatLines.ticks == 1 and runtime.lockdownReplay.ticker ~= nil, "a new batch must start a new ticker")
    restore()
  end

  -- test_relock_mid_batch_with_empty_catcher_resumes_on_next_kick

  do
    local restore = FakeChatLines.Install({ [7] = readable(), [8] = { text = FakeChatLines.SECRET, name = "Arthas-Area52" } })
    local runtime = ReplayRuntime.New()
    ReplayRuntime.Hold(runtime, "CHAT_MSG_WHISPER", 7)
    ReplayRuntime.Hold(runtime, "CHAT_MSG_WHISPER", 8)
    LockdownReplay.Kick(runtime)
    FakeChatLines.Fire()
    FakeChatLines.locked = true
    FakeChatLines.Fire()
    assert(#FakeChatLines.ticks == 0, "setup: the relock must stop the ticker")
    FakeChatLines.locked = false
    assert(runtime.lockdownCatcher.isEmpty(), "setup: the catcher must be drained")
    assert(LockdownReplay.IsPending(runtime), "a drained line still waiting must keep the batch pending")
    LockdownReplay.Kick(runtime)
    assert(#FakeChatLines.ticks == 1, "the next kick must resume the batch")
    restore()
  end
end
