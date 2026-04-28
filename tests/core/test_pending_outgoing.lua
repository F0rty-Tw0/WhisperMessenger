local PendingOutgoing = require("WhisperMessenger.Core.EventRouter.PendingOutgoing")

return function()
  -- Record creates a pending outgoing entry under the canonical conversation key.
  do
    local state = {
      localProfileId = "me",
      pendingOutgoing = {},
      now = function()
        return 100
      end,
    }

    local key = PendingOutgoing.Record(state, {
      channel = "WOW",
      displayName = "Arthas-Area52",
      guid = "Player-1",
    }, "hello")

    assert(key == "wow::WOW::arthas-area52", "unexpected pending key: " .. tostring(key))
    assert(state.pendingOutgoing[key] ~= nil, "pending queue should be created")
    assert(#state.pendingOutgoing[key] == 1, "pending queue should contain one entry")
    assert(state.pendingOutgoing[key][1].text == "hello", "pending entry should keep text")
  end

  -- Consume matches an outgoing inform by GUID/name and removes the pending entry.
  do
    local state = {
      localProfileId = "me",
      pendingOutgoing = {},
      now = function()
        return 100
      end,
    }

    local key = PendingOutgoing.Record(state, {
      channel = "WOW",
      displayName = "Arthas-Area52",
      guid = "Player-1",
    }, "hello")

    local matched = PendingOutgoing.Consume(state, key, {
      channel = "WOW",
      text = "hello",
      playerName = "Arthas",
      guid = "Player-1",
    }, 105)

    assert(matched == true, "pending outgoing should match by guid")
    assert(#state.pendingOutgoing[key] == 0, "matched pending outgoing should be removed")
  end

  -- Consume prunes stale entries and does not match fresh outgoing payloads.
  do
    local state = {
      localProfileId = "me",
      pendingOutgoing = {
        ["wow::WOW::stale"] = {
          {
            text = "old",
            createdAt = 80,
            channel = "WOW",
            guid = "Player-stale",
            displayName = "Stale-Area52",
          },
        },
      },
      now = function()
        return 100
      end,
    }

    local matched = PendingOutgoing.Consume(state, "wow::WOW::fresh", {
      channel = "WOW",
      text = "fresh",
      playerName = "Jaina-Proudmoore",
      guid = "Player-fresh",
    }, 100)

    assert(matched == false, "stale pending outgoing should not match fresh payload")
    assert(#state.pendingOutgoing["wow::WOW::stale"] == 0, "stale pending outgoing should be pruned")
  end
end
