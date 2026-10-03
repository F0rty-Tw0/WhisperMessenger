local Direction = require("WhisperMessenger.Core.Ingest.GroupChatIngest.Direction")

-- "Is this line mine?" for the filters and ingest. A secret guid can't be
-- compared, so it counts as someone else's line.
return function()
  local state = { localPlayerGuid = "Player-1-SELF" }

  -- test_own_guid_is_local
  do
    assert(Direction.IsLocalSender("CHAT_MSG_GUILD", "Player-1-SELF", nil, state) == true, "own guid is the local player")
    assert(Direction.IsLocalSender("CHAT_MSG_GUILD", "Player-1-OTHER", nil, state) == false, "another guid is not")
  end

  -- test_secret_guid_is_never_compared
  do
    local realDetector = Direction._isSecretString
    local compared = false
    rawset(Direction, "_isSecretString", function(value)
      compared = compared or value == "Player-1-SELF"
      return value == "Player-1-SELF"
    end)
    local isSelf = Direction.IsLocalSender("CHAT_MSG_CHANNEL", "Player-1-SELF", nil, state)
    rawset(Direction, "_isSecretString", realDetector)
    assert(compared, "the guid is checked for secrecy first")
    assert(isSelf == false, "a secret guid is treated as another player's line")
  end

  -- test_bn_conversation_uses_the_account_id
  do
    local bnState = { localBnetAccountID = 77 }
    assert(Direction.IsLocalSender("CHAT_MSG_BN_CONVERSATION", nil, 77, bnState) == true, "own BNet account is local")
    assert(Direction.IsLocalSender("CHAT_MSG_BN_CONVERSATION", nil, 78, bnState) == false, "another account is not")
  end
end
