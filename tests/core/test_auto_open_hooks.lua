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
        return { autoOpenIncoming = true, autoOpenOutgoing = true }
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
      isWindowVisible = overrides.isWindowVisible or function()
        return false
      end,
      getActiveConversationKey = overrides.getActiveConversationKey or function()
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
    local result = hooks.onReplyTell()

    assert(result == true, "test_on_reply_tell_opens: should return true on success")
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
    local result = hooks.onReplyTell()

    assert(result == false, "test_on_reply_tell_combat: should return false in combat")
    assert(deps.calls.ensureWindow == 0, "test_on_reply_tell_combat: should not open window in combat")
  end

  -- -----------------------------------------------------------------------
  -- test_on_reply_tell_routes_to_open_window_even_in_combat
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      isInCombat = function()
        return true
      end,
      isWindowVisible = function()
        return true
      end,
      getLastReplyKey = function()
        return "wow::WOW::Arthas"
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    local result = hooks.onReplyTell()

    assert(result == true, "test_on_reply_tell_combat_visible: should route when window already visible")
    assert(deps.calls.ensureWindow == 1, "test_on_reply_tell_combat_visible: should keep routing through messenger")
    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Arthas",
      "test_on_reply_tell_combat_visible: should select reply conversation"
    )
    assert(deps.calls.focusComposer == 1, "test_on_reply_tell_combat_visible: should focus composer")
  end

  -- -----------------------------------------------------------------------
  -- test_on_reply_tell_skipped_when_setting_disabled
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      getSettings = function()
        return { autoOpenIncoming = false, autoOpenOutgoing = false }
      end,
      getLastReplyKey = function()
        return "wow::WOW::Arthas"
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    local result = hooks.onReplyTell()

    assert(result == false, "test_on_reply_tell_disabled: should return false when setting off")
    assert(deps.calls.ensureWindow == 0, "test_on_reply_tell_disabled: should not open window when setting off")
  end

  -- -----------------------------------------------------------------------
  -- test_on_reply_tell_skipped_when_only_incoming_enabled
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      getSettings = function()
        return { autoOpenIncoming = true, autoOpenOutgoing = false }
      end,
      getLastReplyKey = function()
        return "wow::WOW::Arthas"
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    local result = hooks.onReplyTell()

    assert(result == false, "test_on_reply_tell_incoming_only: should return false when only incoming enabled")
    assert(deps.calls.ensureWindow == 0, "test_on_reply_tell_incoming_only: should not open window")
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
    local result = hooks.onReplyTell()

    assert(result == false, "test_on_reply_tell_no_key: should return false when no reply key")
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
    local result = hooks.onSendTell("Jaina")

    assert(result == true, "test_on_send_tell_opens: should return true on success")
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
    local result = hooks.onSendTell("Jaina")

    assert(result == false, "test_on_send_tell_combat: should return false in combat")
    assert(deps.calls.ensureWindow == 0, "test_on_send_tell_combat: should not open window in combat")
  end

  -- -----------------------------------------------------------------------
  -- test_on_send_tell_routes_to_open_window_even_in_combat
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      isInCombat = function()
        return true
      end,
      isWindowVisible = function()
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
    local result = hooks.onSendTell("Jaina")

    assert(result == true, "test_on_send_tell_combat_visible: should route when window already visible")
    assert(deps.calls.ensureWindow == 1, "test_on_send_tell_combat_visible: should keep routing through messenger")
    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Jaina",
      "test_on_send_tell_combat_visible: should select target conversation"
    )
    assert(deps.calls.focusComposer == 1, "test_on_send_tell_combat_visible: should focus composer")
  end

  -- -----------------------------------------------------------------------
  -- test_on_send_tell_skipped_when_setting_disabled
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      getSettings = function()
        return { autoOpenIncoming = false, autoOpenOutgoing = false }
      end,
      findConversationKeyByName = function(name)
        if name == "Jaina" then
          return "wow::WOW::Jaina"
        end
        return nil
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    local result = hooks.onSendTell("Jaina")

    assert(result == false, "test_on_send_tell_disabled: should return false when setting off")
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
    local result = hooks.onSendTell("Unknown")

    assert(result == false, "test_on_send_tell_no_conv: should return false when no key available")
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
    local result = hooks.onOutgoingWhisper("wow::WOW::Arthas")

    assert(result == true, "test_on_outgoing_whisper: should return true on success")
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
    local result = hooks.onOutgoingWhisper(nil)

    assert(result == false, "test_on_outgoing_whisper_nil: should return false when key is nil")
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

  -- -----------------------------------------------------------------------
  -- test_incoming_whisper_does_not_switch_when_window_open_with_active_conversation
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      isWindowVisible = function()
        return true
      end,
      getActiveConversationKey = function()
        return "wow::WOW::Jaina"
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onIncomingWhisper("wow::WOW::Thrall")

    assert(
      #deps.calls.selectConversation == 0,
      "test_incoming_no_switch: should NOT switch conversation when window is open with active conversation, got "
        .. #deps.calls.selectConversation
    )
  end

  -- -----------------------------------------------------------------------
  -- test_incoming_whisper_selects_when_window_open_but_no_active_conversation
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      isWindowVisible = function()
        return true
      end,
      getActiveConversationKey = function()
        return nil
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onIncomingWhisper("wow::WOW::Thrall")

    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Thrall",
      "test_incoming_no_active: should select conversation when window is open but no active conversation"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_incoming_whisper_selects_when_window_not_visible
  -- -----------------------------------------------------------------------
  do
    local deps = makeDeps({
      isWindowVisible = function()
        return false
      end,
      getActiveConversationKey = function()
        return "wow::WOW::Jaina"
      end,
    })

    local hooks = AutoOpenHooks.Create(deps)
    hooks.onIncomingWhisper("wow::WOW::Thrall")

    assert(
      #deps.calls.selectConversation == 1 and deps.calls.selectConversation[1] == "wow::WOW::Thrall",
      "test_incoming_not_visible: should select conversation when window is not visible"
    )
  end
end
