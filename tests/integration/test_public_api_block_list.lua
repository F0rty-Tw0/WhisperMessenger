-- A player blocked through the public API is dropped by the same list ingest reads.
local PublicApiEnv = require("tests.helpers.public_api_env")
local Router = require("WhisperMessenger.Core.EventRouter")

local BOB = "wow::WOW::bob-area52"

local function whisper(runtime, lineID)
  Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", {
    text = "hi",
    playerName = "Bob-Area52",
    guid = "Player-60-0000B0B1",
    lineID = lineID,
  })
end

return function()
  local savedRealm = rawget(_G, "GetNormalizedRealmName")
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)

  local runtime, api = PublicApiEnv.Initialize({})

  -- test_whisper_from_api_blocked_player_is_dropped
  do
    assert(api.Block("Bob-Area52") == true)
    whisper(runtime, 9001)
    assert(runtime.accountState.conversations[BOB] == nil, "a blocked player's whisper creates no conversation")
  end

  -- test_api_block_shows_in_ignore_list
  do
    assert(runtime.accountState.filters.ignored["bob-area52"] ~= nil, "the block is on the settings list")
    assert(api.IsBlocked("bob-area52") == true, "IsBlocked reads the same list")
  end

  -- test_whisper_after_unblock_comes_through
  do
    assert(api.Unblock("Bob-Area52") == true)
    whisper(runtime, 9002)
    local conversation = runtime.accountState.conversations[BOB]
    assert(conversation ~= nil, "an unblocked player's whisper creates a conversation")
    assert(conversation.unreadCount == 1, "one unread whisper, got " .. tostring(conversation.unreadCount))
  end

  PublicApiEnv.Reset()
  rawset(_G, "GetNormalizedRealmName", savedRealm)
end
