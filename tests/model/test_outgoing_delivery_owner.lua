local OutgoingDelivery = require("WhisperMessenger.Model.OutgoingDelivery")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")

-- Whisper history is shared by every character on the account, but a queued
-- message must only ever be sent by the character that wrote it. On other
-- characters it offers Discard only and is left out of the unlock notice.

local function queued(profileId)
  return { direction = "out", kind = "user", text = "gg", delivery = "queued", profileId = profileId }
end

return function()
  -- test_runtime_creation_sets_the_current_character
  do
    RuntimeFactory.CreateRuntimeState({}, {}, "me", {})
    local record = OutgoingDelivery.BuildRecord({ text = "gg" }, 100, "queued")
    assert(record.profileId == "me", "queued record stamped with its character, got " .. tostring(record.profileId))
  end

  -- test_other_characters_queued_message_offers_discard_only
  do
    local actions = OutgoingDelivery.Actions(queued("alt"), false)
    assert(#actions == 1 and actions[1] == "discard", "no Send now on another character")
    local own = OutgoingDelivery.Actions(queued("me"), false)
    assert(own[1] == "send_now" and own[2] == "discard", "own queued message can be sent")
  end

  -- test_unlock_count_skips_other_characters
  do
    local store = { conversations = { k = { messages = { queued("me"), queued("alt") } } } }
    assert(OutgoingDelivery.CountQueued(store) == 1, "only this character's queued messages count")
  end
end
