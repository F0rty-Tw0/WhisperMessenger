local Grouping = require("WhisperMessenger.UI.ChatBubble.Grouping")

return function()
  -- test_channel_context_never_groups_with_whisper
  do
    local whisper = {
      direction = "in",
      kind = "user",
      playerName = "Arthas",
      sentAt = 9000,
    }
    local channelCtx = {
      direction = "in",
      kind = "channel_context",
      playerName = "Arthas",
      sentAt = 9010,
    }

    assert(Grouping.ShouldGroup(whisper, channelCtx) == false, "channel_context should not group with preceding whisper")
    assert(Grouping.ShouldGroup(channelCtx, whisper) == false, "whisper should not group with preceding channel_context")
  end

  -- test_two_channel_context_messages_do_not_group
  do
    local ctx1 = {
      direction = "in",
      kind = "channel_context",
      playerName = "Arthas",
      sentAt = 9000,
    }
    local ctx2 = {
      direction = "in",
      kind = "channel_context",
      playerName = "Arthas",
      sentAt = 9010,
    }

    assert(Grouping.ShouldGroup(ctx1, ctx2) == false, "two channel_context messages should not group")
  end

  -- test_normal_whispers_still_group
  do
    local w1 = {
      direction = "in",
      kind = "user",
      playerName = "Arthas",
      sentAt = 9000,
    }
    local w2 = {
      direction = "in",
      kind = "user",
      playerName = "Arthas",
      sentAt = 9010,
    }

    assert(Grouping.ShouldGroup(w1, w2) == true, "normal whispers should still group")
  end
end
