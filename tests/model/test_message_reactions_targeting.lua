local Targeting = require("WhisperMessenger.Model.MessageReactions.Targeting")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")

local function stateWith(messages)
  return { store = { conversations = { c = { messages = messages } } } }
end

return function()
  -- test_find_target_prefers_newest_matching_fingerprint
  do
    local older = { kind = "user", direction = "in", text = "hi" }
    local newer = { kind = "user", direction = "in", text = "hi" }
    local operation = { type = "reaction", sourceFingerprint = Protocol.Fingerprint("hi") }
    local found = Targeting.FindTarget(stateWith({ older, newer }), "c", operation, "in")
    assert(found == newer, "newest matching message must win")
  end

  -- test_find_target_with_wire_id_requires_matching_id
  do
    local message = { kind = "user", direction = "in", text = "hi", wireId = "abc" }
    local operation = { type = "reaction", wireId = "xyz", sourceFingerprint = Protocol.Fingerprint("hi") }
    assert(Targeting.FindTarget(stateWith({ message }), "c", operation, "in") == nil, "wrong wire id must not match")
  end

  -- test_find_target_respects_direction_for_whisper_reactions
  do
    local message = { kind = "user", direction = "out", text = "hi" }
    local operation = { type = "reaction", sourceFingerprint = Protocol.Fingerprint("hi") }
    assert(Targeting.FindTarget(stateWith({ message }), "c", operation, "in") == nil, "other direction must not match")
  end

  -- test_find_target_group_reaction_matches_name_case_insensitively
  do
    local message = { kind = "user", direction = "out", text = "hi", playerName = "Arthas" }
    local operation = { type = "groupReaction", targetGuid = "", targetName = "arthas", sourceFingerprint = Protocol.Fingerprint("hi") }
    assert(Targeting.FindTarget(stateWith({ message }), "c", operation, "in") == message, "group target name must match")
    operation.targetName = "Jaina"
    assert(Targeting.FindTarget(stateWith({ message }), "c", operation, "in") == nil, "other name must not match")
  end

  -- test_find_target_applies_text_canonicalizer
  do
    local message = { kind = "user", direction = "in", text = "HI" }
    local operation = { type = "reaction", sourceFingerprint = Protocol.Fingerprint("hi") }
    local found = Targeting.FindTarget(stateWith({ message }), "c", operation, "in", string.lower)
    assert(found == message, "canonicalized text must be fingerprinted")
  end

  -- test_find_target_missing_conversation_returns_nil
  do
    assert(Targeting.FindTarget({}, "c", { type = "reaction" }, "in") == nil, "missing conversation must return nil")
  end
end
