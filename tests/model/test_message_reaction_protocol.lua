local loaded, Protocol = pcall(require, "WhisperMessenger.Model.MessageReactionProtocol")

local function isValidUtf8(text)
  local index = 1
  while index <= #text do
    local first = string.byte(text, index)
    local width
    if first < 0x80 then
      width = 1
    elseif first >= 0xC2 and first <= 0xDF then
      width = 2
    elseif first >= 0xE0 and first <= 0xEF then
      width = 3
    elseif first >= 0xF0 and first <= 0xF4 then
      width = 4
    else
      return false
    end

    if index + width - 1 > #text then
      return false
    end
    for offset = 1, width - 1 do
      local continuation = string.byte(text, index + offset)
      if continuation < 0x80 or continuation > 0xBF then
        return false
      end
    end
    index = index + width
  end
  return true
end

return function()
  assert(loaded, "MessageReactionProtocol module should load before protocol behavior can pass")

  local expectedKeys = { "heart", "thumbsup", "laugh", "wow", "sad", "angry", "question", "gg" }
  assert(#Protocol.REACTION_KEYS == #expectedKeys, "protocol should expose exactly eight reaction keys")
  for index, key in ipairs(expectedKeys) do
    assert(Protocol.REACTION_KEYS[index] == key, "reaction key order should match picker order")
    assert(Protocol.IsReactionKey(key) == true, "approved reaction key should validate: " .. key)
  end
  assert(Protocol.IsReactionKey("fire") == false, "unapproved reaction key should be rejected")

  do
    local state = {}
    local first = Protocol.NewWireId(state, 12345)
    local second = Protocol.NewWireId(state, 12345)
    assert(type(first) == "string" and string.match(first, "^[%w]+$"), "wire ID should be compact and opaque")
    assert(#first <= 24, "wire ID should remain compact")
    assert(first ~= second, "wire IDs generated in the same second should be unique")
  end

  do
    local fingerprint = Protocol.Fingerprint("same text")
    assert(
      string.match(fingerprint, "^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$"),
      "fingerprint should be eight lowercase hex bytes"
    )
    assert(fingerprint == Protocol.Fingerprint("same text"), "fingerprint should be deterministic")
    assert(fingerprint ~= Protocol.Fingerprint("different text"), "different text should normally produce a different fingerprint")
  end

  do
    local encoded = Protocol.EncodeIdentity("abc123", "Ready?")
    assert(encoded == "1|I|abc123|ce809d39", "identity payload should use the canonical wire format")
    assert(type(encoded) == "string" and #encoded <= Protocol.MAX_PAYLOAD_BYTES, "identity payload should fit addon cap")
    local decoded = Protocol.Decode(encoded)
    assert(decoded and decoded.type == "identity", "identity payload should decode")
    assert(decoded.wireId == "abc123", "identity wire ID should round-trip")
    assert(decoded.sourceFingerprint == Protocol.Fingerprint("Ready?"), "identity fingerprint should round-trip")
  end

  do
    local fallback = Protocol.BuildFallback("heart", "set", "Ready for the next key?")
    local groupFallback = Protocol.BuildGroupFallback("heart", "set", "Ready for the next key?")
    assert(fallback == "reacted :heart: to: “Ready for the next key?”", "whisper set fallback should omit the actor")
    assert(fallback == groupFallback, "whisper set fallback should match group fallback layout")
    local parsed = Protocol.ParseFallback(fallback)
    assert(parsed and parsed.operation == "set", "set fallback should be recognized")
    assert(parsed.actorName == nil and parsed.key == "heart", "set fallback should parse without an actor")
    assert(parsed.sourceExcerpt == "Ready for the next key?", "set fallback quote should parse")

    local removed = Protocol.BuildFallback("heart", "remove", "Ready for the next key?")
    local groupRemoved = Protocol.BuildGroupFallback("heart", "remove", "Ready for the next key?")
    assert(removed == "removed :heart: from: “Ready for the next key?”", "whisper remove fallback should omit the actor")
    assert(removed == groupRemoved, "whisper remove fallback should match group fallback layout")
    local parsedRemove = Protocol.ParseFallback(removed)
    assert(parsedRemove and parsedRemove.operation == "remove", "remove fallback should be recognized")

    assert(Protocol.ParseFallback("Artio reacted :heart: to: “Ready?”") == nil, "actor-prefixed fallback should not parse")
    assert(Protocol.ParseFallback("reacted :fire: to: “Ready?”") == nil, "fallback with unknown key should not stage")
    assert(Protocol.ParseFallback("not reaction protocol text") == nil, "ordinary whisper should not stage")
  end

  do
    local source = string.rep("é🙂", 100)
    local fallback = Protocol.BuildFallback("question", "set", source)
    assert(#fallback <= Protocol.MAX_WHISPER_BYTES, "fallback should stay within normal whisper cap")
    assert(isValidUtf8(fallback), "fallback truncation should preserve valid UTF-8")
    assert(string.find(fallback, "…”", 1, true) ~= nil, "truncated fallback should end with ellipsis and closing quote")
  end

  do
    local fallback = Protocol.BuildFallback("thumbsup", "set", "duplicate text")
    local encoded = Protocol.EncodeReaction("set", "thumbsup", "wire9", "duplicate text", fallback)
    assert(encoded == "1|R|S|thumbsup|wire9|2e690245|4e448143", "reaction payload should use the canonical wire format")
    local decoded = Protocol.Decode(encoded)
    assert(decoded and decoded.type == "reaction", "reaction payload should decode")
    assert(decoded.operation == "set" and decoded.key == "thumbsup", "reaction operation should round-trip")
    assert(decoded.wireId == "wire9", "reaction target wire ID should round-trip")
    assert(decoded.sourceFingerprint == Protocol.Fingerprint("duplicate text"), "reaction source fingerprint should round-trip")
    assert(decoded.fallbackFingerprint == Protocol.Fingerprint(fallback), "reaction fallback fingerprint should round-trip")

    local legacy = Protocol.Decode(
      Protocol.EncodeReaction("remove", "heart", nil, "legacy text", Protocol.BuildFallback("heart", "remove", "legacy text"))
    )
    assert(legacy and legacy.wireId == nil, "legacy reaction payload should allow an empty wire ID")
  end

  do
    local fallback = Protocol.BuildGroupFallback("heart", "set", "Ready for the next key?")
    assert(fallback == "reacted :heart: to: “Ready for the next key?”", "group set fallback grammar should be fixed English")
    local parsed = Protocol.ParseGroupFallback(fallback)
    assert(parsed and parsed.operation == "set", "group set fallback should be recognized")
    assert(parsed.key == "heart" and parsed.sourceExcerpt == "Ready for the next key?", "group set fallback fields should parse")
    assert(parsed.actorName == nil, "group fallback should not contain an actor")

    local removed = Protocol.BuildGroupFallback("heart", "remove", "Ready for the next key?")
    assert(removed == "removed :heart: from: “Ready for the next key?”", "group remove fallback grammar should be fixed English")
    local parsedRemove = Protocol.ParseGroupFallback(removed)
    assert(parsedRemove and parsedRemove.operation == "remove", "group remove fallback should be recognized")

    assert(Protocol.ParseGroupFallback("Artio reacted :heart: to: “Ready?”") == nil, "actor fallback should not parse as group fallback")
    assert(Protocol.ParseGroupFallback("reacted :fire: to: “Ready?”") == nil, "group fallback with unknown key should not stage")
    assert(Protocol.ParseGroupFallback("not reaction protocol text") == nil, "ordinary group chat should not stage")
  end

  do
    local source = string.rep("é🙂", 100)
    local fallback = Protocol.BuildGroupFallback("question", "set", source)
    local parsed = Protocol.ParseGroupFallback(fallback)
    assert(#fallback <= Protocol.MAX_PAYLOAD_BYTES, "group fallback should stay within addon cap")
    assert(isValidUtf8(fallback), "group fallback truncation should preserve valid UTF-8")
    assert(parsed and parsed.truncated == true, "group fallback parser should report truncation")
    assert(string.find(fallback, "…”", 1, true) ~= nil, "truncated group fallback should end with ellipsis and closing quote")
  end

  do
    local fallback = Protocol.BuildGroupFallback("thumbsup", "set", "duplicate text")
    local encoded = Protocol.EncodeGroupReaction("set", "thumbsup", "wire9", "duplicate text", fallback, "Player-1-ABC", "Thrall-Nagrand")
    assert(type(encoded) == "string" and #encoded <= Protocol.MAX_PAYLOAD_BYTES, "group reaction payload should fit addon cap")
    local decoded = Protocol.Decode(encoded)
    assert(decoded and decoded.type == "groupReaction", "group reaction payload should decode")
    assert(decoded.operation == "set" and decoded.key == "thumbsup", "group reaction operation should round-trip")
    assert(decoded.wireId == "wire9", "group reaction target wire ID should round-trip")
    assert(decoded.sourceFingerprint == Protocol.Fingerprint("duplicate text"), "group reaction source fingerprint should round-trip")
    assert(decoded.fallbackFingerprint == Protocol.Fingerprint(fallback), "group reaction fallback fingerprint should round-trip")
    assert(decoded.targetGuid == "Player-1-ABC" and decoded.targetName == "Thrall-Nagrand", "group reaction target should round-trip")

    local guidOnly = Protocol.Decode(Protocol.EncodeGroupReaction("remove", "heart", nil, "legacy text", "fallback", "Player-1-ABC", ""))
    assert(guidOnly and guidOnly.wireId == nil and guidOnly.targetName == "", "group reaction should allow an empty wire ID and target name")

    local nameOnly = Protocol.Decode(Protocol.EncodeGroupReaction("remove", "heart", nil, "legacy text", "fallback", "", "Thrall-Nagrand"))
    assert(nameOnly and nameOnly.targetGuid == "", "group reaction should allow an empty target GUID")

    assert(
      Protocol.EncodeGroupReaction("toggle", "heart", nil, "text", "fallback", "Player-1-ABC", "") == nil,
      "invalid group operation should not encode"
    )
    assert(Protocol.EncodeGroupReaction("set", "fire", nil, "text", "fallback", "Player-1-ABC", "") == nil, "invalid group key should not encode")
    assert(
      Protocol.EncodeGroupReaction("set", "heart", "bad id", "text", "fallback", "Player-1-ABC", "") == nil,
      "invalid group wire ID should not encode"
    )
    assert(Protocol.EncodeGroupReaction("set", "heart", nil, "text", "fallback", "Player|1", "") == nil, "delimiter in target GUID should not encode")
    assert(
      Protocol.EncodeGroupReaction("set", "heart", nil, "text", "fallback", "", "Thrall|Nagrand") == nil,
      "delimiter in target name should not encode"
    )
    assert(
      Protocol.EncodeGroupReaction("set", "heart", nil, "text", "fallback", false, "Thrall-Nagrand") == nil,
      "non-string target GUID should not encode"
    )
    assert(
      Protocol.EncodeGroupReaction("set", "heart", nil, "text", "fallback", "Player-1-ABC", false) == nil,
      "non-string target name should not encode"
    )
    assert(Protocol.EncodeGroupReaction("set", "heart", nil, "text", "fallback", "", "") == nil, "group reaction needs a target GUID or name")
    assert(
      Protocol.EncodeGroupReaction("set", "heart", nil, "text", "fallback", "", string.rep("x", 256)) == nil,
      "oversized group payload should not encode"
    )

    assert(Protocol.Decode("1|G|S|heart||12345678|12345678|Player-1-ABC|") ~= nil, "known group payload should decode")
    assert(Protocol.Decode("1|G|X|heart||12345678|12345678|Player-1-ABC|") == nil, "invalid group operation should reject")
    assert(Protocol.Decode("1|G|S|fire||12345678|12345678|Player-1-ABC|") == nil, "invalid group key should reject")
    assert(Protocol.Decode("1|G|S|heart|bad id|12345678|12345678|Player-1-ABC|") == nil, "invalid group wire ID should reject")
    assert(Protocol.Decode("1|G|S|heart||12345678|12345678||") == nil, "group payload without target should reject")
    assert(Protocol.Decode("1|G|S|heart||12345678|12345678|Player|1|") == nil, "delimiter-expanded group payload should reject")

    local reaction = Protocol.Decode("1|R|S|heart|wire9|12345678|12345678")
    assert(reaction and reaction.type == "reaction" and reaction.wireId == "wire9", "existing reaction payload should remain unchanged")
  end

  local invalidPayloads = {
    "2|I|abc|12345678",
    "1|X|abc|12345678",
    "1|I|abc|12345678|extra",
    "1|I|bad id|12345678",
    "1|I|abc|xyz",
    "1|R|X|heart|wire|12345678|12345678",
    "1|R|S|fire|wire|12345678|12345678",
    "1|R|S|heart|wire|12345678",
    "1|R|S|heart|bad id|12345678|12345678",
    string.rep("x", Protocol.MAX_PAYLOAD_BYTES + 1),
  }
  for _, payload in ipairs(invalidPayloads) do
    assert(Protocol.Decode(payload) == nil, "invalid payload should be ignored: " .. string.sub(payload, 1, 24))
  end

  assert(Protocol.EncodeIdentity("bad id", "text") == nil, "invalid identity wire ID should not encode")
  assert(Protocol.EncodeReaction("toggle", "heart", "wire", "text", "fallback") == nil, "invalid operation should not encode")
  assert(Protocol.EncodeReaction("set", "fire", "wire", "text", "fallback") == nil, "invalid key should not encode")
end
