local Outbox = require("WhisperMessenger.Core.GroupChat.Outbox")
local GroupChatEnv = require("tests.helpers.group_chat_env")

local function newOutbox(env)
  return Outbox.New({
    chatApi = env.chatApi,
    timer = env.timer,
    now = function()
      return env.clock
    end,
    random = function()
      return 1
    end,
  })
end

return function()
  -- test_send_whispers_every_frame_to_every_recipient
  do
    local env = GroupChatEnv.New()
    local outbox = newOutbox(env)
    local count = outbox.Send({ "Anna-Kazzak", "Bela-Kazzak" }, "M~abcd1234~" .. string.rep("x", 300))
    assert(count == 2, "two recipients")
    assert(#env.sent == 4, "two frames each, got " .. #env.sent)
    for _, call in ipairs(env.sent) do
      assert(call.prefix == "WMGC" and call.channel == "WHISPER", "addon whisper on the group chat prefix")
    end
    assert(env.sent[1].target == "Anna-Kazzak" and env.sent[3].target == "Bela-Kazzak", "frames go out per recipient in order")
    env.restore()
  end

  -- test_throttled_frames_retry_later_in_order
  do
    local env = GroupChatEnv.New()
    local outbox = newOutbox(env)
    env.refuse = 1
    outbox.Send({ "Anna-Kazzak", "Bela-Kazzak" }, "M~abcd1234~hi")
    assert(#env.sent == 0, "the refused frame holds the queue")
    assert(outbox.PendingCount() == 2, "both frames wait")
    outbox.Send({ "Csilla-Kazzak" }, "M~abcd1234~again")
    assert(#env.sent == 0, "new frames wait behind the throttled ones")
    env.runTimers()
    assert(#env.sent == 3, "everything goes out on the retry")
    assert(env.sent[1].target == "Anna-Kazzak" and env.sent[3].target == "Csilla-Kazzak", "order kept")
    env.restore()
  end

  -- test_a_frame_is_dropped_after_max_attempts
  do
    local env = GroupChatEnv.New()
    local outbox = newOutbox(env)
    env.refuse = Outbox.MAX_ATTEMPTS
    outbox.Send({ "Anna-Kazzak" }, "M~abcd1234~hi")
    for _ = 1, Outbox.MAX_ATTEMPTS do
      env.runTimers()
    end
    assert(outbox.PendingCount() == 0, "the frame is given up")
    assert(#env.sent == 0)
    env.restore()
  end

  -- test_not_found_marks_the_recipient_offline_for_a_while
  do
    local env = GroupChatEnv.New()
    local outbox = newOutbox(env)
    outbox.Send({ "Anna-Kazzak", "Bela-Ragnaros" }, "M~abcd1234~hi")
    assert(outbox.HasRecentSends(), "a send can still be answered")
    assert(outbox.ClaimNotFound("No player named 'Someone' is currently playing.") == nil, "other names are not ours")
    assert(outbox.ClaimNotFound("No player named 'Anna' is currently playing.") == "Anna-Kazzak", "same-realm short name matches")
    assert(outbox.ClaimNotFound("No player named 'Bela-Ragnaros' is currently playing.") == "Bela-Ragnaros", "full name matches")
    env.sent = {}
    assert(outbox.Send({ "Anna-Kazzak", "Bela-Ragnaros" }, "M~abcd1234~again") == 0, "offline members are skipped")
    assert(#env.sent == 0)
    outbox.MarkOnline("anna-kazzak")
    assert(outbox.Send({ "Anna-Kazzak" }, "M~abcd1234~back") == 1, "hearing from them clears the skip")
    env.clock = env.clock + Outbox.OFFLINE_SKIP_SECONDS + 1
    assert(not outbox.IsSkipped("Bela-Ragnaros"), "the skip runs out")
    env.restore()
  end

  -- test_not_found_is_only_matched_shortly_after_a_send
  do
    local env = GroupChatEnv.New()
    local outbox = newOutbox(env)
    outbox.Send({ "Anna-Kazzak" }, "M~abcd1234~hi")
    env.clock = env.clock + Outbox.NOT_FOUND_WINDOW + 1
    assert(not outbox.HasRecentSends())
    assert(outbox.ClaimNotFound("No player named 'Anna' is currently playing.") == nil, "too late to be ours")
    env.restore()
  end

  -- test_unframeable_bodies_are_refused
  do
    local env = GroupChatEnv.New()
    local outbox = newOutbox(env)
    assert(outbox.Send({ "Anna-Kazzak" }, string.rep("x", 5000)) == nil)
    env.restore()
  end
end
