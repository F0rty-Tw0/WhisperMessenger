local Decode = require("WhisperMessenger.Model.MessageReactionProtocol.Decode")

return function()
  -- test_decode_reads_identity_payload
  do
    local decoded = Decode.Decode("1|I|abc|0a1b2c3d")
    assert(decoded and decoded.type == "identity", "identity payload must decode")
    assert(decoded.wireId == "abc" and decoded.sourceFingerprint == "0a1b2c3d", "identity fields must carry over")
  end

  -- test_decode_reads_reaction_without_wire_id
  do
    local decoded = Decode.Decode("1|R|D|heart||0a1b2c3d|11112222")
    assert(decoded and decoded.type == "reaction" and decoded.operation == "remove", "reaction payload must decode")
    assert(decoded.wireId == nil and decoded.fallbackFingerprint == "11112222", "empty wire id must decode as nil")
  end

  -- test_decode_reads_group_reaction_target
  do
    local decoded = Decode.Decode("1|G|S|fire|abc|0a1b2c3d|11112222|Player-1-0001|Arthas")
    assert(decoded and decoded.type == "groupReaction" and decoded.operation == "set", "group payload must decode")
    assert(decoded.targetGuid == "Player-1-0001" and decoded.targetName == "Arthas", "group target must carry over")
  end

  -- test_decode_rejects_group_reaction_without_target
  do
    assert(Decode.Decode("1|G|S|fire|abc|0a1b2c3d|11112222||") == nil, "group payload needs a GUID or name")
  end

  -- test_decode_rejects_wrong_version_and_bad_fields
  do
    assert(Decode.Decode("2|I|abc|0a1b2c3d") == nil, "unknown version must fail")
    assert(Decode.Decode("1|R|X|heart||0a1b2c3d|11112222") == nil, "unknown operation must fail")
    assert(Decode.Decode("1|R|S|nope||0a1b2c3d|11112222") == nil, "unknown key must fail")
    assert(Decode.Decode("") == nil, "empty payload must fail")
  end
end
