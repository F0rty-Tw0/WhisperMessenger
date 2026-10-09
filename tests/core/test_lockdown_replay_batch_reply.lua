local FakeChatLines = require("tests.helpers.fake_chat_lines")
local ReplayRuntime = require("tests.helpers.lockdown_replay_runtime")
local LockdownReplay = require("WhisperMessenger.Core.Bootstrap.LockdownReplay")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local Router = require("WhisperMessenger.Core.EventRouter")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local Store = require("WhisperMessenger.Model.ConversationStore")

local SECRET = FakeChatLines.SECRET
local ARTHAS = "wow::WOW::arthas-area52"
local JAINA = "wow::WOW::jaina-area52"

local function from(name, text)
  return { text = text or "held hello", name = name, guid = "Player-1-" .. name }
end

local function seedMuted(runtime, conversationKey, playerName)
  Store.AppendIncoming(runtime.store, conversationKey, {
    id = "seed",
    direction = "in",
    kind = "user",
    text = "seed",
    sentAt = 100,
    lineID = 90,
    playerName = playerName,
  }, false)
  runtime.store.conversations[conversationKey].muted = true
end

local function liveWhisper(runtime, name, lineID, at)
  runtime.now = function()
    return at
  end
  -- stylua: ignore
  EventBridge.RouteLiveEvent(runtime, runtime.refreshWindow, "CHAT_MSG_WHISPER",
    "live hi", name, nil, nil, nil, nil, nil, nil, nil, nil, lineID, "Player-1-" .. name)
end

return function()
  -- test_r_targets_latest_received_at_filed_incoming

  do
    -- Jaina arrived first but only reads back on the second tick, after Arthas.
    local lines = { [7] = { text = SECRET, name = "Jaina-Area52" }, [8] = from("Arthas-Area52") }
    local probe = ReplayRuntime.Probe(lines, { { "CHAT_MSG_WHISPER", 7, 501 }, { "CHAT_MSG_WHISPER", 8, 502 } })
    LockdownReplay.Kick(probe.runtime)
    FakeChatLines.Fire()
    lines[7] = from("Jaina-Area52")
    FakeChatLines.Fire()
    assert(probe.runtime.lockdownReplay.lastSummary.filed == 2, "setup: both whispers must file")
    local target = probe.runtime.lastIncomingWhisperKey
    assert(target == ARTHAS, "R must target the latest arrival, got " .. tostring(target))
    probe.restore()
  end

  -- test_live_whisper_mid_batch_keeps_r

  do
    local lines = { [7] = from("Arthas-Area52"), [8] = { text = SECRET, name = "Arthas-Area52" } }
    local probe = ReplayRuntime.Probe(lines, { { "CHAT_MSG_WHISPER", 7 }, { "CHAT_MSG_WHISPER", 8 } })
    LockdownReplay.Kick(probe.runtime)
    FakeChatLines.Fire()
    liveWhisper(probe.runtime, "Jaina-Area52", 60, 1000)
    lines[8] = from("Arthas-Area52", "second")
    FakeChatLines.Fire()
    assert(probe.runtime.lockdownReplay.lastSummary ~= nil, "setup: the batch must finish")
    local target = probe.runtime.lastIncomingWhisperKey
    assert(target == JAINA, "a live whisper mid-batch must keep R, got " .. tostring(target))
    probe.restore()
  end

  -- test_live_whisper_before_first_tick_newer_than_held_keeps_r

  do
    local probe = ReplayRuntime.Probe({ [7] = from("Arthas-Area52") }, { { "CHAT_MSG_WHISPER", 7 } })
    LockdownReplay.Kick(probe.runtime)
    liveWhisper(probe.runtime, "Jaina-Area52", 60, 1000)
    FakeChatLines.Fire()
    assert(probe.runtime.lockdownReplay.lastSummary ~= nil, "setup: the batch must finish")
    local target = probe.runtime.lastIncomingWhisperKey
    assert(target == JAINA, "a live whisper newer than the held one must keep R, got " .. tostring(target))
    probe.restore()
  end

  -- test_live_whisper_mid_batch_from_pre_batch_r_conversation_keeps_r

  do
    local lines = { [7] = from("Arthas-Area52"), [8] = { text = SECRET, name = "Arthas-Area52" } }
    local probe = ReplayRuntime.Probe(lines, { { "CHAT_MSG_WHISPER", 7 }, { "CHAT_MSG_WHISPER", 8 } })
    liveWhisper(probe.runtime, "Jaina-Area52", 60, 400)
    LockdownReplay.Kick(probe.runtime)
    FakeChatLines.Fire()
    liveWhisper(probe.runtime, "Jaina-Area52", 61, 1000)
    lines[8] = from("Arthas-Area52", "second")
    FakeChatLines.Fire()
    assert(probe.runtime.lockdownReplay.lastSummary ~= nil, "setup: the batch must finish")
    local target = probe.runtime.lastIncomingWhisperKey
    assert(target == JAINA, "a newer live whisper from the pre-batch R conversation must keep R, got " .. tostring(target))
    probe.restore()
  end

  -- test_held_whisper_newer_than_last_live_moves_r

  do
    local probe = ReplayRuntime.Probe({ [7] = from("Arthas-Area52") }, { { "CHAT_MSG_WHISPER", 7 } })
    liveWhisper(probe.runtime, "Jaina-Area52", 60, 400)
    LockdownReplay.Kick(probe.runtime)
    FakeChatLines.Fire()
    local target = probe.runtime.lastIncomingWhisperKey
    assert(target == ARTHAS, "a held whisper newer than the last live one must move R, got " .. tostring(target))
    probe.restore()
  end

  -- test_second_batch_does_not_reuse_previous_alert_or_reply_target

  do
    local lines = { [7] = from("Arthas-Area52"), [8] = from("Jaina-Area52") }
    local probe = ReplayRuntime.Probe(lines, { { "CHAT_MSG_WHISPER", 7 } })
    LockdownReplay.Kick(probe.runtime)
    FakeChatLines.Fire()
    assert(#probe.notified == 1, "setup: the first batch must alert")
    seedMuted(probe.runtime, JAINA, "Jaina-Area52")
    ReplayRuntime.Hold(probe.runtime, "CHAT_MSG_WHISPER", 8)
    LockdownReplay.Kick(probe.runtime)
    FakeChatLines.Fire()
    assert(#probe.notified == 1, "a muted-only second batch must not alert, got " .. #probe.notified)
    local target = probe.runtime.lastIncomingWhisperKey
    assert(target == JAINA, "mute skips the alert, never the R target, got " .. tostring(target))
    probe.restore()
  end

  -- test_later_frame_degrade_raises_no_alert

  do
    local now = 400
    local probe = ReplayRuntime.Probe({ [7] = from("Arthas-Area52", Protocol.BuildFallback("sad", "set", "Visible")) })
    local runtime = probe.runtime
    runtime.now = function()
      return now
    end
    FakeChatLines.DeferAfter()
    local target = { kind = "user", direction = "out", text = "Visible", wireId = "target3", sentAt = 390 }
    runtime.store.conversations[ARTHAS] = {
      conversationKey = ARTHAS,
      messages = { target },
      unreadCount = 0,
      lastPreview = target.text,
      lastActivityAt = target.sentAt,
    }
    Router.HandleEvent(runtime, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = "2|R|S|heart|target3|12345678|12345678",
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    ReplayRuntime.HELD_AT = 401
    ReplayRuntime.Hold(runtime, "CHAT_MSG_WHISPER", 7)
    ReplayRuntime.HELD_AT = 500
    LockdownReplay.Kick(runtime)
    FakeChatLines.Fire()
    assert(runtime.lockdownReplay.lastSummary ~= nil, "setup: the batch must finish")
    -- stylua: ignore
    EventBridge.RouteLiveEvent(runtime, runtime.refreshWindow, "CHAT_MSG_WHISPER",
      "live hi", "Jaina-Area52", nil, nil, nil, nil, nil, nil, nil, nil, 60, "Player-1-Jaina")
    local notifiedBefore = #probe.notified
    local refreshesBefore = #probe.refreshes
    now = 420
    FakeChatLines.FlushAfter()
    assert(#runtime.store.conversations[ARTHAS].messages == 2, "setup: the fallback must degrade into history")
    assert(#probe.notified == notifiedBefore, "a later degrade must not alert")
    local last = probe.refreshes[#probe.refreshes]
    assert(#probe.refreshes > refreshesBefore and last.key == ARTHAS, "a later degrade must refresh its conversation")
    probe.restore()
  end
end
