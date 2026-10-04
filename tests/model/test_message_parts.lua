local MessageParts = require("WhisperMessenger.Model.MessageParts")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local MessageReplies = require("WhisperMessenger.Model.MessageReplies")

-- The manifest side message that pairs parts 2..n of a long whisper, and
-- the part fields every pairing site copies onto a message.

local PARTS = {
  { text = "first part" },
  { text = "second part", join = " " },
  { text = "third", join = "" },
}

return function()
  -- test_encode_manifest_lists_fingerprints_and_joins_of_parts_two_to_n
  do
    local payload = MessageParts.EncodeManifest("abc1", PARTS)
    local expected = "1|P|abc1|3|" .. Protocol.Fingerprint("second part") .. "," .. Protocol.Fingerprint("third") .. "|sn"
    assert(payload == expected, "manifest: " .. tostring(payload))
  end

  -- test_encode_manifest_needs_two_parts_and_a_wire_id
  do
    assert(MessageParts.EncodeManifest("abc1", { PARTS[1] }) == nil, "one part needs no manifest")
    assert(MessageParts.EncodeManifest("bad|id", PARTS) == nil, "invalid wire id")
  end

  -- test_decode_manifest_expands_into_identity_records
  do
    local manifest = MessageParts.DecodeManifest(MessageParts.EncodeManifest("abc1", PARTS))
    assert(manifest and manifest.type == "manifest" and manifest.wireId == "abc1", "decoded")
    assert(#manifest.records == 2, "one record per part 2..n")
    local second, third = manifest.records[1], manifest.records[2]
    assert(second.type == "identity" and second.wireId == "abc1", "identity record")
    assert(second.sourceFingerprint == Protocol.Fingerprint("second part"), "part 2 fingerprint")
    assert(second.partIndex == 2 and second.partCount == 3 and second.join == " ", "part 2 fields")
    assert(third.partIndex == 3 and third.partCount == 3 and third.join == "", "part 3 fields")
  end

  -- test_protocol_decode_delegates_manifests
  do
    local decoded = Protocol.Decode(MessageParts.EncodeManifest("abc1", PARTS))
    assert(decoded and decoded.type == "manifest" and #decoded.records == 2, "Decode returns the manifest")
  end

  -- test_malformed_manifests_are_rejected
  do
    local fp = Protocol.Fingerprint("x")
    local bad = {
      "1|P|abc1|3|" .. fp .. "|sn",
      "1|P|abc1|2|" .. fp .. "|sn",
      "1|P|abc1|2|" .. fp .. "|x",
      "1|P|abc1|1||",
      "1|P||2|" .. fp .. "|s",
      "1|P|abc1|2|nothex00|s",
      "2|P|abc1|2|" .. fp .. "|s",
      "1|P|abc1|2|" .. fp .. "|s|extra",
    }
    for _, payload in ipairs(bad) do
      assert(Protocol.Decode(payload) == nil, "rejected: " .. payload)
      assert(MessageParts.DecodeManifest(payload) == nil, "decoder rejects: " .. payload)
    end
  end

  -- test_presence_and_reply_decoders_ignore_manifests
  do
    local payload = MessageParts.EncodeManifest("abc1", PARTS)
    assert(LivePresence.Decode(payload) == nil, "presence decoder rejects kind P")
    assert(MessageReplies.DecodeLink(payload) == nil, "reply decoder rejects kind P")
  end

  -- test_apply_metadata_copies_part_fields_only
  do
    local message = { text = "hi", wireId = "keep" }
    MessageParts.ApplyMetadata(message, { partIndex = 2, partCount = 4, join = " ", wireId = "other", text = "no" })
    assert(message.partIndex == 2 and message.partCount == 4 and message.join == " ", "part fields copied")
    assert(message.wireId == "keep" and message.text == "hi", "nothing else copied")
  end

  -- test_apply_metadata_without_part_fields_changes_nothing
  do
    local message = { text = "hi" }
    MessageParts.ApplyMetadata(message, { wireId = "w1" })
    MessageParts.ApplyMetadata(message, nil)
    assert(message.partIndex == nil and message.partCount == nil and message.join == nil, "unchanged")
  end
end
