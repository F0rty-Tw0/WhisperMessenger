local SecretString = require("WhisperMessenger.Core.Ingest.GroupChatIngest.SecretString")

-- Secrets are found through issecretvalue: comparing one, even inside a
-- pcall, logs a blocked action in taint.log.
return function()
  local saved = rawget(_G, "issecretvalue")
  local SECRET_NAME = "Secret-Realm"

  -- test_value_flagged_by_api_reads_as_secret
  do
    rawset(_G, "issecretvalue", function(value)
      return value == SECRET_NAME
    end)
    assert(SecretString.IsSecretString(SECRET_NAME) == true, "a value issecretvalue flags must read as secret")
  end

  -- test_plain_value_reads_as_not_secret
  do
    rawset(_G, "issecretvalue", function(value)
      return value == SECRET_NAME
    end)
    assert(SecretString.IsSecretString("Arthas") == false, "a plain value must not read as secret")
  end

  -- test_nothing_is_secret_without_the_api
  do
    rawset(_G, "issecretvalue", nil)
    assert(SecretString.IsSecretString(SECRET_NAME) == false, "without issecretvalue nothing is secret")
  end

  -- test_payload_with_secret_sender_has_secret_fields
  do
    rawset(_G, "issecretvalue", function(value)
      return value == SECRET_NAME
    end)
    local payload = { text = "hi", playerName = SECRET_NAME, guid = "Player-1-0001" }
    assert(SecretString.PayloadHasSecretFields(payload) == true, "a secret sender must flag the payload")
  end

  rawset(_G, "issecretvalue", saved)
end
