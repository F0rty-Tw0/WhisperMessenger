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
  assert(type(runtime.collapseIndex) == "table" and next(runtime.collapseIndex) == nil, "the collapse index starts empty")

  local fresh = { conversations = {} }
  RuntimeFactory.CreateRuntimeState(fresh, { activeConversationKey = nil }, "testplayer", {})
  assert(type(fresh.filters) == "table" and type(fresh.filters.ignored) == "table", "old saved variables get filters")
end
