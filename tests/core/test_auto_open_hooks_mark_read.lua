local AutoOpenHooks = require("WhisperMessenger.Core.Bootstrap.AutoOpenHooks")

-- A whisper started in the game's own chat that WM does not take over
-- (routing off) counts as read there.
return function()
  local function makeDeps(overrides)
    local calls = { markRead = {}, selectConversation = {}, buildKey = 0, ensure = 0 }
    local deps = {
      getSettings = function()
        return { autoOpenOutgoing = overrides.routing == true }
      end,
      isInCombat = function()
        return false
      end,
      ensureWindow = function() end,
      setWindowVisible = function() end,
      selectConversation = function(key)
        calls.selectConversation[#calls.selectConversation + 1] = key
      end,
      focusComposer = function() end,
      findConversationKeyByName = function(name)
        return overrides.keysByName and overrides.keysByName[name] or nil
      end,
      buildConversationKeyFromName = function(_name)
        calls.buildKey = calls.buildKey + 1
        return "built-key"
      end,
      ensureConversation = function()
        calls.ensure = calls.ensure + 1
      end,
      isWindowVisible = function()
        return false
      end,
      markRead = function(key)
        calls.markRead[#calls.markRead + 1] = key == nil and "nil" or key
      end,
      calls = calls,
    }
    return deps
  end

  -- test_unrouted_send_tell_marks_existing_conversation_read
  do
    local deps = makeDeps({ keysByName = { Thrall = "k1" } })
    local hooks = AutoOpenHooks.Create(deps)
    local routed = hooks.onSendTell("Thrall")
    assert(routed == false, "game chat keeps the whisper")
    assert(#deps.calls.markRead == 1 and deps.calls.markRead[1] == "k1", "the existing conversation is marked read")
  end

  -- test_unrouted_send_tell_creates_nothing
  do
    local deps = makeDeps({})
    local hooks = AutoOpenHooks.Create(deps)
    hooks.onSendTell("Nobody")
    assert(deps.calls.buildKey == 0, "no key is built for an unknown name")
    assert(deps.calls.ensure == 0, "no conversation is created")
    assert(deps.calls.markRead[1] == "nil" or deps.calls.markRead[1] == nil, "nothing real is marked")
  end

  -- test_unrouted_send_tell_without_name_marks_nothing
  do
    local deps = makeDeps({})
    local hooks = AutoOpenHooks.Create(deps)
    hooks.onSendTell(nil)
    assert(#deps.calls.markRead == 0, "no name, no mark")
  end

  -- test_unrouted_outgoing_bnet_marks_read
  do
    local deps = makeDeps({})
    local hooks = AutoOpenHooks.Create(deps)
    local routed = hooks.onOutgoingWhisper("bn-key")
    assert(routed == false, "game chat keeps the whisper")
    assert(#deps.calls.markRead == 1 and deps.calls.markRead[1] == "bn-key", "the BNet conversation is marked read")
  end

  -- test_routed_send_tell_unchanged
  do
    local deps = makeDeps({ routing = true, keysByName = { Thrall = "k1" } })
    local hooks = AutoOpenHooks.Create(deps)
    local routed = hooks.onSendTell("Thrall")
    assert(routed == true, "WM still takes over the whisper")
    assert(#deps.calls.markRead == 0, "a routed whisper is not marked read here")
    assert(deps.calls.selectConversation[1] == "k1", "the conversation is selected as before")
  end

  -- test_routed_outgoing_whisper_unchanged
  do
    local deps = makeDeps({ routing = true })
    local hooks = AutoOpenHooks.Create(deps)
    assert(hooks.onOutgoingWhisper("bn-key") == true, "WM still takes over the whisper")
    assert(#deps.calls.markRead == 0, "a routed whisper is not marked read here")
  end

  -- test_missing_mark_read_dep_is_a_no_op
  do
    local deps = makeDeps({ keysByName = { Thrall = "k1" } })
    deps.markRead = nil
    local hooks = AutoOpenHooks.Create(deps)
    assert(hooks.onSendTell("Thrall") == false, "older callers without markRead still work")
    assert(hooks.onOutgoingWhisper("k1") == false, "older callers without markRead still work")
  end
end
