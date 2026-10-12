local SecretValue = require("WhisperMessenger.Util.SecretValue")

-- One check for 12.0 secret values; without the API nothing is secret.
return function()
  local saved = rawget(_G, "issecretvalue")
  local SECRET = {}

  -- test_secret_value_reads_as_secret
  do
    rawset(_G, "issecretvalue", function(value)
      return value == SECRET
    end)
    assert(SecretValue.Is(SECRET) == true, "a secret value must read as secret")
  end

  -- test_plain_value_reads_as_not_secret
  do
    rawset(_G, "issecretvalue", function(value)
      return value == SECRET
    end)
    assert(SecretValue.Is("Arthas") == false, "a plain value must not read as secret")
  end

  -- test_nothing_is_secret_without_the_api
  do
    rawset(_G, "issecretvalue", nil)
    assert(SecretValue.Is(SECRET) == false, "without issecretvalue nothing is secret")
  end

  rawset(_G, "issecretvalue", saved)
end
