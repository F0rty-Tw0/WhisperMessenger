local AutoOpenHooks = require("WhisperMessenger.Core.Bootstrap.AutoOpenHooks")

return function()
  -- -----------------------------------------------------------------------
  -- Helpers
  -- -----------------------------------------------------------------------
  local function makeDeps(overrides)
    overrides = overrides or {}
    local calls = {
      ensureWindow = 0,
      setWindowVisible = {},
      selectConversation = {},
      focusComposer = 0,
    }

    return {
      getSettings = overrides.getSettings or function()
        return { autoOpenWindow = true }
      end,
      isInCombat = overrides.isInCombat or function()
        return false
      end,
      ensureWindow = function()
        calls.ensureWindow = calls.ensureWindow + 1
      end,
      setWindowVisible = function(visible)
        calls.setWindowVisible[#calls.setWindowVisible + 1] = visible
      end,
      selectConversation = function(key)
        calls.selectConversation[#calls.selectConversation + 1] = key
      end,
      focusComposer = function()
        calls.focusComposer = calls.focusComposer + 1
      end,
      findConversationKeyByName = overrides.findConversationKeyByName or function(_name)
        return nil
      end,
      getLastReplyKey = overrides.getLastReplyKey or function()
        return nil
      end,
      calls = calls,
    }
  end

  -- -----------------------------------------------------------------------
  -- test_on_reply_tell_opens_window_and_selects_conversation
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      getLastReplyKey = function()
        return "wow::WOW::Arthas"
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onReplyTell()

    assert(
      deps.calls.ensureWindow == 1,
      "test_on_reply_tell_opens: ensureWindow should be called once, got " .. deps.calls.ensureWindow
    )
    assert(
      #deps.calls.setWindowVisible == 1 and deps.calls.setWindowVisible[1] == true,
      "test_on_reply_tell_opens: should call setWindowVisible(true)"
    )
    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Arthas",
      "test_on_reply_tell_opens: should select Arthas conversation"
    )
    assert(deps.calls.focusComposer == 1, "test_on_reply_tell_opens: should force focus composer")
  end

  -- -----------------------------------------------------------------------
  -- test_on_reply_tell_skipped_in_combat
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      isInCombat = function()
        return true
      end,
      getLastReplyKey = function()
        return "wow::WOW::Arthas"
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onReplyTell()

    assert(deps.calls.ensureWindow == 0, "test_on_reply_tell_combat: should not open window in combat")
  end

  -- -----------------------------------------------------------------------
  -- test_on_reply_tell_skipped_when_setting_disabled
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      getSettings = function()
        return { autoOpenWindow = false }
      end,
      getLastReplyKey = function()
        return "wow::WOW::Arthas"
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onReplyTell()

    assert(deps.calls.ensureWindow == 0, "test_on_reply_tell_disabled: should not open window when setting off")
  end

  -- -----------------------------------------------------------------------
  -- test_on_reply_tell_skipped_when_no_key
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      getLastReplyKey = function()
        return nil
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onReplyTell()

    assert(deps.calls.ensureWindow == 0, "test_on_reply_tell_no_key: should not open window when no reply key")
  end

  -- -----------------------------------------------------------------------
  -- test_on_send_tell_opens_window_and_selects_conversation
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      findConversationKeyByName = function(name)
        if name == "Jaina" then
          return "wow::WOW::Jaina"
        end
        return nil
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onSendTell("Jaina")

    assert(deps.calls.ensureWindow == 1, "test_on_send_tell_opens: ensureWindow should be called once")
    assert(
      #deps.calls.setWindowVisible == 1 and deps.calls.setWindowVisible[1] == true,
      "test_on_send_tell_opens: should call setWindowVisible(true)"
    )
    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Jaina",
      "test_on_send_tell_opens: should select Jaina conversation"
    )
    assert(deps.calls.focusComposer == 1, "test_on_send_tell_opens: should force focus composer")
  end

  -- -----------------------------------------------------------------------
  -- test_on_send_tell_skipped_in_combat
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      isInCombat = function()
        return true
      end,
      findConversationKeyByName = function(name)
        if name == "Jaina" then
          return "wow::WOW::Jaina"
        end
        return nil
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onSendTell("Jaina")

    assert(deps.calls.ensureWindow == 0, "test_on_send_tell_combat: should not open window in combat")
  end

  -- -----------------------------------------------------------------------
  -- test_on_send_tell_skipped_when_setting_disabled
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      getSettings = function()
        return { autoOpenWindow = false }
      end,
      findConversationKeyByName = function(name)
        if name == "Jaina" then
          return "wow::WOW::Jaina"
        end
        return nil
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onSendTell("Jaina")

    assert(deps.calls.ensureWindow == 0, "test_on_send_tell_disabled: should not open window when setting off")
  end

  -- -----------------------------------------------------------------------
  -- test_on_send_tell_falls_back_to_build_key_when_no_conversation
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      findConversationKeyByName = function(_name)
        return nil
      end,
    })
    deps.buildConversationKeyFromName = function(name)
      return "wow::WOW::" .. name
    end

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onSendTell("Unknown")

    assert(
      deps.calls.ensureWindow == 1,
      "test_on_send_tell_fallback: ensureWindow should be called when key built from name"
    )
    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Unknown",
      "test_on_send_tell_fallback: should select conversation from built key"
    )
    assert(deps.calls.focusComposer == 1, "test_on_send_tell_fallback: should force focus composer")
  end

  -- -----------------------------------------------------------------------
  -- test_on_send_tell_skipped_when_no_conversation_and_no_builder
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      findConversationKeyByName = function(_name)
        return nil
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onSendTell("Unknown")

    assert(
      deps.calls.ensureWindow == 0,
      "test_on_send_tell_no_conv: should not open window when no matching conversation and no builder"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_on_outgoing_whisper_opens_window_with_force_focus
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps()

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onOutgoingWhisper("wow::WOW::Arthas")

    assert(deps.calls.ensureWindow == 1, "test_on_outgoing_whisper: ensureWindow should be called once")
    assert(
      #deps.calls.setWindowVisible == 1 and deps.calls.setWindowVisible[1] == true,
      "test_on_outgoing_whisper: should call setWindowVisible(true)"
    )
    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Arthas",
      "test_on_outgoing_whisper: should select Arthas conversation"
    )
    assert(deps.calls.focusComposer == 1, "test_on_outgoing_whisper: should force focus composer")
  end

  -- -----------------------------------------------------------------------
  -- test_on_outgoing_whisper_skipped_when_nil_key
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps()

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onOutgoingWhisper(nil)

    assert(deps.calls.ensureWindow == 0, "test_on_outgoing_whisper_nil: should not open when key is nil")
  end

  -- -----------------------------------------------------------------------
  -- test_on_auto_open_incoming_opens_window_and_selects
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps()

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onIncomingWhisper("wow::WOW::Thrall")

    assert(deps.calls.ensureWindow == 1, "test_on_auto_open_incoming: ensureWindow should be called once")
    assert(
      #deps.calls.setWindowVisible == 1 and deps.calls.setWindowVisible[1] == true,
      "test_on_auto_open_incoming: should call setWindowVisible(true)"
    )
    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Thrall",
      "test_on_auto_open_incoming: should select Thrall conversation"
    )
    assert(
      deps.calls.focusComposer == 0,
      "test_on_auto_open_incoming: should NOT force focus composer (respects autoFocusComposer)"
    )
  end
end
