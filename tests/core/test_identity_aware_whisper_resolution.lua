local Identity = require("WhisperMessenger.Model.Identity")
local ConversationOps = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local ChatReplyState = require("WhisperMessenger.Util.ChatReplyState")
local MythicSuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")

local function makeEditBox(attributes)
  return {
    GetAttribute = function(_, key)
      return attributes[key]
    end,
    SetAttribute = function(_, key, value)
      attributes[key] = value
    end,
    GetText = function()
      return ""
    end,
  }
end

return function()
  local resolve = Identity.ResolveWhisperConversation
  assert(type(resolve) == "function", "expected one shared identity-aware whisper resolver")

  -- Group display names must never win over compatible character whisper rows.
  do
    local runtime = {
      store = {
        conversations = {
          group = { channel = "PARTY", displayName = "Jaina" },
          wow = { channel = "WOW", displayName = "Jaina-Area52" },
        },
      },
    }

    assert(
      ConversationOps.findConversationKeyByName(runtime, "Jaina") == "wow",
      "auto-open must ignore a group row whose latest sender matches the whisper target"
    )
  end

  -- Battle.net auto-open must not reuse a group conversation carrying the same numeric sender ID.
  do
    local runtime = {
      localProfileId = "me",
      store = {
        conversations = {
          group = { channel = "BN_CONVERSATION", displayName = "Friend#1234", bnetAccountID = 42 },
        },
      },
    }
    local key = ConversationOps.ensureBattleNetConversation(runtime, Identity, {
      bnetAccountID = 42,
      battleTag = "Friend#1234",
    })

    assert(key ~= "group", "Battle.net auto-open must ignore group rows with matching sender IDs")
    assert(runtime.store.conversations[key].channel == "BN", "Battle.net auto-open must create a direct BN conversation")
  end

  -- A requested realm is exact identity, not an unordered base-name candidate.
  do
    local runtime = {
      store = {
        conversations = {
          area52 = { channel = "WOW", displayName = "Arthas-Area52" },
          stormrage = { channel = "WOW", displayName = "Arthas-Stormrage" },
        },
      },
    }

    assert(resolve(runtime, "Arthas-Area52", "WOW") == "area52", "exact realm must win")
  end

  -- A bare name only resolves when its existing character whisper match is unique.
  do
    local runtime = {
      store = {
        conversations = {
          area52 = { channel = "WOW", displayName = "Arthas-Area52" },
          stormrage = { channel = "WOW", displayName = "Arthas-Stormrage" },
        },
      },
    }

    assert(resolve(runtime, "Arthas", "WOW") == nil, "ambiguous base name must not select an arbitrary realm")
  end

  -- A stale Battle.net reply resolves the existing BN conversation by its persisted identifier.
  do
    local runtime = {
      localProfileId = "me",
      store = {
        conversations = {
          friend = {
            channel = "BN",
            displayName = "Friend#1234",
            bnetAccountID = 42,
            battleTag = "Friend#1234",
            messages = {},
          },
        },
      },
    }
    local attributes = {
      chatType = "BN_WHISPER",
      stickyType = "BN_WHISPER",
      tellTarget = 42,
    }

    local key, resolved = ChatReplyState.CaptureStaleWhisperReplyTarget(runtime, function()
      return 1
    end, function()
      return makeEditBox(attributes)
    end)

    assert(key == "friend", "stale Battle.net reply must recover the existing BN conversation")
    assert(resolved == true, "resolved Battle.net reply must allow sticky state cleanup")
    assert(runtime.lastIncomingWhisperKey == "friend", "recovered BN key must become the reply target")
    assert(runtime.store.conversations.friend.channel == "BN", "recovery must preserve the Battle.net channel")
    assert(runtime.store.conversations.friend.bnetAccountID == 42, "recovery must preserve the Battle.net identifier")
  end

  -- An unknown Battle.net reply must leave Blizzard's state intact on Mythic resume.
  do
    local savedSuspended = _G._wmSuspended
    local attributes = {
      chatType = "BN_WHISPER",
      stickyType = "BN_WHISPER",
      tellTarget = 999,
    }
    local runtime = {
      store = { conversations = {} },
      accountState = { settings = {} },
    }

    MythicSuspendController.Attach(runtime, {
      Bootstrap = {},
      getNumChatWindows = function()
        return 1
      end,
      getEditBox = function()
        return makeEditBox(attributes)
      end,
      print = function() end,
    })
    runtime.resume()

    assert(attributes.chatType == "BN_WHISPER", "unresolved BN reply state must not be scrubbed")
    assert(attributes.stickyType == "BN_WHISPER", "unresolved BN sticky state must not be changed")
    assert(attributes.tellTarget == 999, "unresolved BN reply target must remain available to Blizzard")
    _G._wmSuspended = savedSuspended
  end
end
