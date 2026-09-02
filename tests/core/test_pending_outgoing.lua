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
    assert(state.pendingOutgoing[key] == nil, "matched pending queue should be removed when empty")
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
    assert(state.pendingOutgoing["wow::WOW::stale"] == nil, "stale pending queue should be removed when empty")
  end
  -- Record prunes old pending sends even if no outgoing inform arrives.
  do
    local now = 100
    local state = {
      localProfileId = "me",
      pendingOutgoing = {},
      now = function()
        return now
      end,
    }

    local firstKey = PendingOutgoing.Record(state, {
      channel = "WOW",
      displayName = "Arthas-Area52",
      guid = "Player-1",
    }, "old")

    now = 116
    PendingOutgoing.Record(state, {
      channel = "WOW",
      displayName = "Jaina-Proudmoore",
      guid = "Player-2",
    }, "fresh")

    assert(state.pendingOutgoing[firstKey] == nil, "stale pending queue should be removed during later records")
  end
  -- Resolve preserves its first two return values and also exposes metadata.
  do
    local state = {
      localProfileId = "me",
      pendingOutgoing = {},
      now = function()
        return 100
      end,
    }
    local key = PendingOutgoing.Record(
      state,
      {
        channel = "WOW",
        displayName = "Arthas-Area52",
        guid = "Player-1",
      },
      "reaction fallback",
      {
        wireId = "wire1",
        reactionControl = {
          operation = "set",
          key = "heart",
        },
      }
    )

    local fromPending, pendingText, entry = PendingOutgoing.Resolve(state, key, {
      channel = "WOW",
      text = "reaction fallback",
      playerName = "Arthas",
      guid = "Player-1",
    }, 105)

    assert(fromPending == true, "extended pending entry should still resolve")
    assert(pendingText == "reaction fallback", "Resolve second return should remain pending text")
    assert(entry and entry.wireId == "wire1", "Resolve should expose consumed wire ID")
    assert(entry.reactionControl and entry.reactionControl.key == "heart", "Resolve should expose reaction control metadata")
  end
  -- A secret BNet ID comparison must be a non-match, not abort event routing.
  do
    local secretIdMeta = {
      __eq = function()
        error("attempt to compare a secret number value", 0)
      end,
    }
    local pendingId = setmetatable({}, secretIdMeta)
    local payloadId = setmetatable({}, secretIdMeta)
    local key = "bnet::BN::secret"
    local state = {
      pendingOutgoing = {
        [key] = {
          {
            channel = "BN",
            bnetAccountID = pendingId,
            createdAt = 100,
            text = "hello",
          },
        },
      },
    }

    local ok, matched = pcall(PendingOutgoing.Consume, state, key, {
      channel = "BN",
      bnetAccountID = payloadId,
      text = "hello",
    }, 105)

    assert(ok, "secret BNet ID equality must not abort outgoing event routing")
    assert(matched == false, "failed BNet ID comparison must be a non-match")
    assert(#state.pendingOutgoing[key] == 1, "non-matching pending entry must remain queued")
  end
end
