local FakeChatLines = require("tests.helpers.fake_chat_lines")
local ReplayRuntime = require("tests.helpers.lockdown_replay_runtime")
local LockdownReplay = require("WhisperMessenger.Core.Bootstrap.LockdownReplay")
local Store = require("WhisperMessenger.Model.ConversationStore")
local WidgetPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")

local SECRET = FakeChatLines.SECRET
local KEY = "wow::WOW::arthas-area52"

local function from(name, text)
  return { text = text or "held hello", name = name, guid = "Player-1-" .. name }
end

local function whispers(count)
  local lines, holds = {}, {}
  for lineID = 1, count do
    lines[lineID] = from("Arthas-Area52", "held " .. lineID)
    holds[lineID] = { "CHAT_MSG_WHISPER", lineID }
  end
  return lines, holds
end

local function replay(probe)
  LockdownReplay.Kick(probe.runtime)
  ReplayRuntime.FireUntilDone(probe.runtime)
end

local function widgetPreview(probe)
  return WidgetPreview.Create({ accountState = probe.runtime.accountState, runtimeStore = probe.runtime.store })
end

local function contacts()
  return { { conversationKey = KEY, channel = "WOW", displayName = "Arthas-Area52" } }
end

local function printedText(probe)
  return probe.printed[1] and probe.printed[1][1]
end

return function()
  -- test_one_summary_line_per_batch

  do
    local probe = ReplayRuntime.Probe(whispers(3))
    replay(probe)
    assert(#probe.printed == 1, "a batch must print one line, got " .. #probe.printed)
    assert(printedText(probe) == "3 whispers arrived during the fight.", "got " .. tostring(printedText(probe)))
    probe.restore()
  end

  -- test_singular_summary

  do
    local probe = ReplayRuntime.Probe(whispers(1))
    replay(probe)
    assert(printedText(probe) == "1 whisper arrived during the fight.", "got " .. tostring(printedText(probe)))
    probe.restore()
  end

  -- test_lost_line_printed

  do
    local lines = { [7] = { text = "gone", name = "Arthas-Area52", valid = false } }
    local probe = ReplayRuntime.Probe(lines, { { "CHAT_MSG_WHISPER", 7 } })
    replay(probe)
    local expected = "1 whisper from the fight couldn't be recovered — check your chat."
    assert(#probe.printed == 1 and printedText(probe) == expected, "got " .. tostring(printedText(probe)))
    probe.restore()
  end

  -- test_no_line_when_nothing_filed_or_lost

  do
    local probe = ReplayRuntime.Probe({ [7] = from("Arthas-Area52", "my reply") }, { { "CHAT_MSG_WHISPER_INFORM", 7 } })
    replay(probe)
    assert(probe.runtime.lockdownReplay.lastSummary ~= nil, "setup: the batch must finish")
    assert(#probe.printed == 0, "an outgoing-only batch must print nothing")
    probe.restore()
  end

  -- test_at_most_one_alert_per_batch

  do
    local probe = ReplayRuntime.Probe(whispers(3))
    replay(probe)
    assert(#probe.notified == 1, "three alerting whispers must alert once, got " .. #probe.notified)
    probe.restore()
  end

  -- test_muted_conversation_stays_silent

  do
    local probe = ReplayRuntime.Probe(whispers(1))
    Store.AppendIncoming(probe.runtime.store, KEY, {
      id = "seed",
      direction = "in",
      kind = "user",
      text = "seed",
      sentAt = 100,
      lineID = 90,
      playerName = "Arthas-Area52",
    }, false)
    probe.runtime.store.conversations[KEY].muted = true
    replay(probe)
    assert(probe.runtime.lockdownReplay.lastSummary.filed == 1, "setup: the whisper must file")
    assert(#probe.notified == 0, "a muted conversation must not alert")
    probe.restore()
  end

  -- test_batch_end_refreshes_window_once

  do
    local probe = ReplayRuntime.Probe(whispers(3))
    replay(probe)
    assert(#probe.refreshes == 1, "a batch must refresh the window once, got " .. #probe.refreshes)
    probe.restore()
  end

  -- test_batch_raises_no_widget_preview

  do
    local probe = ReplayRuntime.Probe(whispers(2))
    replay(probe)
    assert(probe.runtime.lockdownReplay.lastSummary.filed == 2, "setup: the whispers must file")
    local preview = widgetPreview(probe).buildLatestIncomingPreview(contacts())
    assert(preview == nil, "a replayed batch must not pop the widget preview, got " .. tostring(preview and preview.messageText))
    probe.restore()
  end

  -- test_whisper_after_the_lift_still_previews

  do
    local probe = ReplayRuntime.Probe(whispers(1))
    replay(probe)
    Store.AppendIncoming(probe.runtime.store, KEY, {
      id = "live",
      direction = "in",
      kind = "user",
      text = "after the fight",
      sentAt = 1000,
      lineID = 99,
      playerName = "Arthas-Area52",
    }, false)
    local preview = widgetPreview(probe).buildLatestIncomingPreview(contacts())
    assert(preview and preview.messageText == "after the fight", "a newer live whisper must still preview")
    probe.restore()
  end

  -- test_relock_mid_batch_keeps_counts_one_summary

  do
    local lines = { [7] = from("Arthas-Area52"), [8] = { text = SECRET, name = "Arthas-Area52" } }
    local probe = ReplayRuntime.Probe(lines, { { "CHAT_MSG_WHISPER", 7 }, { "CHAT_MSG_WHISPER", 8 } })
    LockdownReplay.Kick(probe.runtime)
    FakeChatLines.Fire()
    FakeChatLines.locked = true
    FakeChatLines.Fire()
    FakeChatLines.locked = false
    lines[8] = from("Arthas-Area52", "second")
    LockdownReplay.Kick(probe.runtime)
    FakeChatLines.Fire()
    assert(#probe.printed == 1, "a relocked batch must still print once, got " .. #probe.printed)
    assert(printedText(probe) == "2 whispers arrived during the fight.", "got " .. tostring(printedText(probe)))
    assert(#probe.notified == 1, "a relocked batch must still alert once, got " .. #probe.notified)
    probe.restore()
  end
end
