local Wire = require("WhisperMessenger.Model.MessageReactionProtocol.Wire")

return function()
  -- test_is_reaction_key_accepts_only_known_keys
  do
    assert(Wire.IsReactionKey("heart") == true, "heart must be a reaction key")
    assert(Wire.IsReactionKey("Heart") == false, "keys are case-sensitive")
    assert(Wire.IsReactionKey(nil) == false, "nil is not a reaction key")
  end

  -- test_is_wire_id_requires_one_to_32_alphanumerics
  do
    assert(Wire.IsWireId("abc123") == true, "alphanumeric id must pass")
    assert(Wire.IsWireId("") == false, "empty id must fail")
    assert(Wire.IsWireId(string.rep("a", 33)) == false, "33-char id must fail")
    assert(Wire.IsWireId("ab|c") == false, "separator in id must fail")
  end

  -- test_is_fingerprint_requires_eight_lowercase_hex_digits
  do
    assert(Wire.IsFingerprint("0a1b2c3d") == true, "8 lowercase hex digits must pass")
    assert(Wire.IsFingerprint("0A1B2C3D") == false, "uppercase hex must fail")
    assert(Wire.IsFingerprint("0a1b2c3") == false, "7 digits must fail")
  end

  -- test_is_safe_group_target_rejects_field_separator
  do
    assert(Wire.IsSafeGroupTarget("Arthas") == true, "plain name must pass")
    assert(Wire.IsSafeGroupTarget("Art|has") == false, "separator must fail")
    assert(Wire.IsSafeGroupTarget(nil) == false, "nil must fail")
  end
end
