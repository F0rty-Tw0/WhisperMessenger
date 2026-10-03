local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

-- "Ignore…" from a contact row or a message adds the player to the account
-- ignore list and refreshes the window.
return function()
  rawset(_G, "time", function()
    return 1000
  end)

  -- test_ignore_player_adds_an_entry_with_the_reason
  do
    local refreshes = 0
    local accountState = {}
    local callbacks = WindowCallbacks.Create({
      runtime = {},
      accountState = accountState,
      characterState = {},
      refreshWindow = function()
        refreshes = refreshes + 1
      end,
    })
    callbacks.onIgnorePlayer("Spammer-Realm", "spam")
    local entry = accountState.filters.ignored["spammer-realm"]
    assert(entry ~= nil, "player ignored")
    assert(entry.reason == "spam", "reason saved")
    assert(entry.addedAt == 1000, "added now")
    assert(refreshes == 1, "window refreshed")
  end

  -- test_ignore_player_without_a_name_does_nothing
  do
    local refreshes = 0
    local accountState = { filters = { ignored = {}, rules = {} } }
    local callbacks = WindowCallbacks.Create({
      runtime = {},
      accountState = accountState,
      characterState = {},
      refreshWindow = function()
        refreshes = refreshes + 1
      end,
    })
    callbacks.onIgnorePlayer(nil, "spam")
    assert(next(accountState.filters.ignored) == nil, "nothing ignored")
    assert(refreshes == 0, "no refresh")
  end

  rawset(_G, "time", nil)
end
