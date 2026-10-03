local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")

-- Loading the runtime backfills the filter lists, sweeps ignore entries that
-- expired while the player was offline, and starts an empty collapse index.
return function()
  local accountState = {
    conversations = {},
    filters = {
      ignored = {
        expired = { name = "Expired", addedAt = 0, expiresAt = 50, blocked = 0 },
        forever = { name = "Forever", addedAt = 0, blocked = 0 },
      },
    },
  }
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, { activeConversationKey = nil }, "testplayer", {
    now = function()
      return 100
    end,
  })

  assert(accountState.filters.ignored.expired == nil, "an entry that expired offline is swept at load")
  assert(accountState.filters.ignored.forever ~= nil, "a forever entry stays")
  assert(type(accountState.filters.rules) == "table", "missing keyword rules are backfilled")
  assert(accountState.filters.rules[1] ~= nil and accountState.filters.rules[1].presetId ~= nil, "preset rules are seeded at load")
  assert(type(runtime.collapseIndex) == "table" and next(runtime.collapseIndex) == nil, "the collapse index starts empty")

  local Store = require("WhisperMessenger.Model.ConversationStore")
  Store.EnsureConversation(runtime.store, "channel::testplayer::trade")
  runtime.collapseIndex["channel::testplayer::trade"] = {}
  Store.Remove(runtime.store, "channel::testplayer::trade")
  assert(runtime.collapseIndex["channel::testplayer::trade"] == nil, "a removed chat drops its collapse entries")

  local fresh = { conversations = {} }
  RuntimeFactory.CreateRuntimeState(fresh, { activeConversationKey = nil }, "testplayer", {})
  assert(type(fresh.filters) == "table" and type(fresh.filters.ignored) == "table", "old saved variables get filters")
  assert(type(fresh.settings) == "table" and type(fresh.settings.enabledChannels) == "table", "old saved variables get an empty channel picker")
  assert(next(fresh.settings.enabledChannels) == nil, "no channel is a chat until the player turns it on")

  -- test_hide_channels_from_default_chat_defaults_on
  assert(fresh.settings.hideChannelsFromDefaultChat == true, "channel chats hide their lines from game chat by default")
  local optedOut = { conversations = {}, settings = { hideChannelsFromDefaultChat = false } }
  RuntimeFactory.CreateRuntimeState(optedOut, { activeConversationKey = nil }, "testplayer", {})
  assert(optedOut.settings.hideChannelsFromDefaultChat == false, "a saved choice to keep channel lines stays")
end
