local MessageReactions = require("WhisperMessenger.Model.MessageReactions")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")

-- Pairing a whisper with its identity record copies the part fields of a
-- long whisper along with the wire id, whichever arrives first.

local PART_RECORD = {
  type = "identity",
  wireId = "abc1",
  sourceFingerprint = Protocol.Fingerprint("second part"),
  partIndex = 2,
  partCount = 3,
  join = " ",
}

local function newState()
  return {
    store = { conversations = {} },
    now = function()
      return 0
    end,
  }
end

return function()
  -- test_record_first_then_whisper_copies_part_fields
  do
    local state = newState()
    MessageReactions.RecordIdentity(state, "thrall", "k", PART_RECORD, 0)
    local message = { text = "second part" }
    assert(MessageReactions.AttachIncomingIdentity(state, "thrall", "k", message, 0) == true, "paired")
    assert(message.wireId == "abc1", "wire id copied")
    assert(message.partIndex == 2 and message.partCount == 3 and message.join == " ", "part fields copied")
  end

  -- test_whisper_first_then_record_copies_part_fields
  do
    local state = newState()
    local message = { text = "second part" }
    MessageReactions.AttachIncomingIdentity(state, "thrall", "k", message, 0)
    local paired = MessageReactions.RecordIdentity(state, "thrall", "k", PART_RECORD, 0)
    assert(paired == message and message.wireId == "abc1", "paired")
    assert(message.partIndex == 2 and message.partCount == 3 and message.join == " ", "part fields copied")
  end
end
