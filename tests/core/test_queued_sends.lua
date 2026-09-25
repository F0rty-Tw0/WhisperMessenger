local QueuedSends = require("WhisperMessenger.Core.Bootstrap.QueuedSends")
local Localization = require("WhisperMessenger.Locale.Localization")
local OutgoingDelivery = require("WhisperMessenger.Model.OutgoingDelivery")

-- Queued sends never go out on their own: Send now (a click) sends the
-- original text to the original target once the lock has lifted; Discard
-- drops it. Retry (a click) sends a failed message again: same text, same
-- target. The old record goes once the send is under way; if the player is
-- still offline the game's "No player named" line brings a fresh "(Not sent)".

local KEY = "me::WOW::thrall"

-- locked: { value = bool }; tests flip it to raise or lift the lock.
local function newRuntime(locked)
  locked = locked or { value = false }
  local queued = {
    id = "1",
    direction = "out",
    kind = "user",
    text = "later",
    target = "Thrall-Nagrand",
    playerName = "Thrall",
    channel = "WOW",
    guid = "Player-1",
    delivery = "queued",
    replyTo = { wireId = "w9" },
  }
  local failed = {
    id = "2",
    direction = "out",
    kind = "user",
    text = "oops",
    target = "Thrall-Nagrand",
    playerName = "Thrall",
    channel = "WOW",
    replyTo = { wireId = "w8" },
    delivery = "failed",
  }
  local conversation = { messages = { queued, failed } }
  local runtime = {
    store = { conversations = { [KEY] = conversation } },
    isMythicLockdown = function()
      return locked.value
    end,
    isCompetitiveContent = function()
      return false
    end,
  }
  return runtime, queued, failed, conversation
end

local function fakeSendHandler(result, calls)
  return {
    HandleSend = function(_runtime, payload)
      calls[#calls + 1] = payload
      return result
    end,
  }
end

return function()
  Localization.Configure({ language = "enUS" })
  local refreshes = 0
  local function refresh()
    refreshes = refreshes + 1
  end

  -- test_send_now_while_locked_keeps_it_queued
  do
    local runtime, queued = newRuntime({ value = true })
    local calls = {}
    local result = QueuedSends.HandleAction(runtime, KEY, queued, "send_now", fakeSendHandler(true, calls), refresh)
    assert(result == false and #calls == 0, "never sends while the lock is on")
    assert(runtime.store.conversations[KEY].messages[1] == queued, "stays queued")
  end

  -- test_send_now_sends_original_text_to_original_target
  do
    local runtime, queued = newRuntime()
    local calls = {}
    local result = QueuedSends.HandleAction(runtime, KEY, queued, "send_now", fakeSendHandler(true, calls), refresh)
    assert(result == true and #calls == 1, "sent once")
    local p = calls[1]
    assert(p.conversationKey == KEY and p.target == "Thrall-Nagrand" and p.displayName == "Thrall", "original target")
    assert(p.text == "later" and p.channel == "WOW" and p.guid == "Player-1", "original text")
    assert(p.replyTo and p.replyTo.wireId == "w9", "reply link travels with it")
    assert(#runtime.store.conversations[KEY].messages == 1, "queued record removed; the sent copy arrives at the bottom")
  end

  -- test_send_now_that_cannot_send_keeps_the_record
  do
    local runtime, queued = newRuntime()
    QueuedSends.HandleAction(runtime, KEY, queued, "send_now", fakeSendHandler(false, {}), refresh)
    assert(runtime.store.conversations[KEY].messages[1] == queued, "still queued when the send did not go out")
  end

  -- test_send_now_refuses_another_characters_message
  do
    OutgoingDelivery.SetLocalProfileId("me")
    local runtime, queued = newRuntime()
    queued.profileId = "alt"
    local calls = {}
    assert(QueuedSends.HandleAction(runtime, KEY, queued, "send_now", fakeSendHandler(true, calls), refresh) == false, "not sent")
    assert(#calls == 0, "never sent from another character")
    OutgoingDelivery.SetLocalProfileId(nil)
  end

  -- test_discard_removes
  do
    local runtime, queued = newRuntime({ value = true })
    assert(QueuedSends.HandleAction(runtime, KEY, queued, "discard", fakeSendHandler(true, {}), refresh) == true, "discarded")
    assert(runtime.store.conversations[KEY].messages[1] ~= queued, "gone")
  end

  -- test_retry_resends_the_same_text_to_the_same_target
  do
    local runtime, _, failed, conversation = newRuntime()
    local calls = {}
    assert(QueuedSends.HandleAction(runtime, KEY, failed, "retry", fakeSendHandler(true, calls), refresh) == true, "sent")
    assert(#calls == 1 and calls[1].text == "oops" and calls[1].target == "Thrall-Nagrand", "same text, same target")
    assert(calls[1].conversationKey == KEY and calls[1].replyTo == failed.replyTo, "same chat, same reply")
    assert(#conversation.messages == 1 and conversation.messages[1] ~= failed, "old record removed")
  end

  -- test_retry_leaves_the_typed_draft_alone
  do
    local runtime, _, failed, conversation = newRuntime()
    conversation.draft = "brb"
    QueuedSends.HandleAction(runtime, KEY, failed, "retry", fakeSendHandler(true, {}), refresh)
    assert(conversation.draft == "brb", "typed text untouched")
  end

  -- test_retry_that_cannot_send_keeps_the_message
  do
    local runtime, _, failed, conversation = newRuntime()
    assert(QueuedSends.HandleAction(runtime, KEY, failed, "retry", fakeSendHandler(false, {}), refresh) == false, "not sent")
    assert(conversation.messages[2] == failed, "failed message stays so the text is not lost")
  end

  -- test_retry_only_applies_to_failed_messages
  do
    local runtime, queued = newRuntime()
    local calls = {}
    QueuedSends.HandleAction(runtime, KEY, queued, "retry", fakeSendHandler(true, calls), refresh)
    assert(#calls == 0, "queued messages use Send now")
  end

  -- test_unlock_prints_one_line_when_messages_wait
  do
    local lines = {}
    rawset(_G, "DEFAULT_CHAT_FRAME", {
      AddMessage = function(_, text)
        lines[#lines + 1] = text
      end,
    })
    local locked = { value = false }
    local runtime = newRuntime(locked)
    runtime.refreshWindow = refresh
    QueuedSends.OnLockStateChanged(runtime)
    assert(#lines == 0, "no notice without a lock having been seen")
    locked.value = true
    QueuedSends.OnLockStateChanged(runtime)
    assert(#lines == 0, "no notice while locked")
    locked.value = false
    local before = refreshes
    QueuedSends.OnLockStateChanged(runtime)
    assert(#lines == 1, "one line when the lock lifts")
    assert(string.find(lines[1], "1 queued message is waiting", 1, true), "counts the queued messages: " .. lines[1])
    assert(string.find(lines[1], "WhisperMessenger", 1, true), "addon chat prefix")
    assert(refreshes == before + 1, "window refreshed so Send now appears")
    QueuedSends.OnLockStateChanged(runtime)
    assert(#lines == 1, "no repeat while unlocked")

    runtime.store.conversations[KEY].messages[3] = { direction = "out", kind = "user", delivery = "queued" }
    locked.value = true
    QueuedSends.OnLockStateChanged(runtime)
    locked.value = false
    QueuedSends.OnLockStateChanged(runtime)
    assert(string.find(lines[2], "2 queued messages are waiting", 1, true), "plural: " .. tostring(lines[2]))

    runtime.store.conversations[KEY].messages = {}
    locked.value = true
    QueuedSends.OnLockStateChanged(runtime)
    locked.value = false
    QueuedSends.OnLockStateChanged(runtime)
    assert(#lines == 2, "nothing queued: no notice")
    rawset(_G, "DEFAULT_CHAT_FRAME", nil)
  end
end
