local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

-- "Clear on logout" is a privacy promise: an error in the cleanup that runs
-- for each removed chat must not leave any chat in the saved variables.

local NOW = 1000
local KEYS = { "me::WOW::jaina", "me::WOW::thrall", "me::PARTY::party", "channel::me::trade" }

local function build()
  local conversations = {}
  for _, key in ipairs(KEYS) do
    conversations[key] = { conversationKey = key, messages = { { id = "1", text = "hi", sentAt = NOW } }, lastActivityAt = NOW }
  end
  local accountState = { settings = { clearOnLogout = true }, conversations = conversations }
  local characterState = { activeConversationKey = KEYS[1] }
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, "me", {
    now = function()
      return NOW
    end,
  })
  ChannelMessageStore.Record(runtime.channelMessageStore, "Thrall-Realm", "WTS sword", "Trade", NOW, 2)
  return runtime, accountState, characterState
end

return function()
  -- test_logout_clears_everything_when_the_removal_cleanup_throws
  do
    local runtime, accountState, characterState = build()
    runtime.onConversationRemoved = function()
      error("cleanup failed")
    end

    local ok = pcall(Presence.handlePlayerLogout, { runtime = runtime })

    assert(ok, "logout does not raise when a cleanup fails")
    assert(next(accountState.conversations) == nil, "no chat is left to save")
    assert(accountState.channelMessages.entryCount == 0, "no channel line is left to save")
    assert(characterState.activeConversationKey == nil, "the saved selection is cleared")
    assert(runtime.activeConversationKey == nil, "the session selection is cleared")
  end
end
