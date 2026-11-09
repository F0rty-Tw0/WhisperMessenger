local ChannelMessageKey = require("WhisperMessenger.Model.ChannelMessageKey")

return function()
  -- test_normalize_lowercases_name_and_realm
  do
    local key = ChannelMessageKey.Normalize("Thrall-Area52")
    assert(key == "thrall-area52", "expected thrall-area52, got: " .. tostring(key))
  end

  -- test_normalize_strips_spaces_hyphens_and_apostrophes_from_the_realm
  do
    local spaced = ChannelMessageKey.Normalize("Thrall-Area 52")
    assert(spaced == "thrall-area52", "spaces must go, got: " .. tostring(spaced))
    local hyphenated = ChannelMessageKey.Normalize("Thrall-Azjol-Nerub")
    assert(hyphenated == "thrall-azjolnerub", "hyphens must go, got: " .. tostring(hyphenated))
    local apostrophe = ChannelMessageKey.Normalize("Thrall-Kel'Thuzad")
    assert(apostrophe == "thrall-kelthuzad", "apostrophes must go, got: " .. tostring(apostrophe))
  end

  -- test_normalize_empty_realm_gives_the_bare_name
  do
    local trailing = ChannelMessageKey.Normalize("Thrall-")
    assert(trailing == "thrall", "empty realm should give the bare name, got: " .. tostring(trailing))
    local bare = ChannelMessageKey.Normalize("Thrall")
    assert(bare == "thrall", "bare name should stay bare, got: " .. tostring(bare))
  end

  -- test_normalize_secret_or_non_string_is_empty
  do
    assert(ChannelMessageKey.Normalize(nil) == "", "nil should normalize to empty")
    assert(ChannelMessageKey.Normalize(42) == "", "a number should normalize to empty")

    local saved = rawget(_G, "issecretvalue")
    rawset(_G, "issecretvalue", function(value)
      return value == "Secret-Realm"
    end)
    local secret = ChannelMessageKey.Normalize("Secret-Realm")
    rawset(_G, "issecretvalue", saved)
    assert(secret == "", "a secret name should normalize to empty, got: " .. tostring(secret))
  end

  -- test_base_and_has_realm
  do
    assert(ChannelMessageKey.Base("thrall-area52") == "thrall", "base should drop the realm")
    assert(ChannelMessageKey.HasRealm("thrall-area52") == true, "a realm key has a realm")
    assert(ChannelMessageKey.Base("thrall") == "thrall", "a bare key is its own base")
    assert(ChannelMessageKey.HasRealm("thrall") == false, "a bare key has no realm")
  end
end
