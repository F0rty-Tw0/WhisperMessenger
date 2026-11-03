local Fallback = require("WhisperMessenger.Model.MessageReactionProtocol.Fallback")

return function()
  -- test_build_group_fallback_quotes_source_text
  do
    local text = Fallback.BuildGroupFallback("heart", "set", "hello", Fallback.ADDON_HINT_SUFFIX)
    assert(text == "reacted :heart: to: “hello” (via WhisperMessenger)", "unexpected fallback: " .. tostring(text))
  end

  -- test_build_group_fallback_rejects_unknown_key
  do
    assert(Fallback.BuildGroupFallback("nope", "set", "hello") == nil, "unknown key must not build")
  end

  -- test_parse_group_fallback_round_trips_remove
  do
    local text = Fallback.BuildGroupFallback("fire", "remove", "gg", Fallback.ADDON_HINT_SUFFIX)
    local parsed = Fallback.ParseGroupFallback(text)
    assert(parsed and parsed.operation == "remove" and parsed.key == "fire", "remove fallback must parse back")
    assert(parsed.sourceExcerpt == "gg" and parsed.truncated == false, "excerpt must survive untruncated")
  end

  -- test_parse_group_fallback_flags_truncated_excerpt
  do
    local text = Fallback.BuildGroupFallback("heart", "set", string.rep("x", 300))
    local parsed = Fallback.ParseGroupFallback(text)
    assert(parsed and parsed.truncated == true, "long source must parse as truncated")
  end

  -- test_parse_group_fallback_ignores_plain_chat
  do
    assert(Fallback.ParseGroupFallback("reacted to your message") == nil, "plain chat must not parse")
  end
end
