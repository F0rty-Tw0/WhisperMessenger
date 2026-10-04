local ChatFilters = require("WhisperMessenger.Core.Bootstrap.ChatFilters")

return function()
  -- test_register_routes_through_securecall

  -- Raw ChatFrame_AddMessageEventFilter calls taint Blizzard's filter
  -- dispatch table. The next CHAT_MSG_WHISPER iteration propagates taint
  -- into ChatEdit_SetLastTellTarget, crashing /r and R-keybind. Fix is to
  -- wrap both register/unregister calls in securecall so the mutation
  -- happens inside Blizzard's own function body.
  do
    local savedAdd = _G.ChatFrame_AddMessageEventFilter
    local savedRemove = _G.ChatFrame_RemoveMessageEventFilter
    local savedSecurecall = _G.securecall

    local invocationLog = {}
    rawset(_G, "ChatFrame_AddMessageEventFilter", function(event, _fn)
      table.insert(invocationLog, { via = "raw_add", event = event })
    end)
    rawset(_G, "ChatFrame_RemoveMessageEventFilter", function(event, _fn)
      table.insert(invocationLog, { via = "raw_remove", event = event })
    end)

    local securecallInvocations = {}
    rawset(_G, "securecall", function(fn, ...)
      table.insert(securecallInvocations, { fn = fn, args = { ... } })
      return fn(...)
    end)

    local Bootstrap = {
      _inCompetitiveContent = false,
      _inMythicContent = false,
      _inEncounter = false,
    }
    local accountState = { settings = { hideFromDefaultChat = true } }

    ChatFilters.Configure(Bootstrap, accountState)
    Bootstrap.syncChatFilters()

    assert(Bootstrap._filtersRegistered == true, "filters should register when hideFromDefaultChat=true and no restriction active")
    assert(#securecallInvocations == 4, "expected 4 securecall invocations (one per whisper event), got " .. #securecallInvocations)

    local sawAddTarget = false
    for _, entry in ipairs(securecallInvocations) do
      if entry.fn == _G.ChatFrame_AddMessageEventFilter then
        sawAddTarget = true
        break
      end
    end
    assert(sawAddTarget, "securecall must be invoked with _G.ChatFrame_AddMessageEventFilter as the target fn")

    -- Now test unregister path
    securecallInvocations = {}
    Bootstrap._inEncounter = true
    Bootstrap.syncChatFilters()

    assert(Bootstrap._filtersRegistered == false, "filters should unregister during encounter")
    assert(#securecallInvocations == 4, "expected 4 securecall invocations on unregister, got " .. #securecallInvocations)
    local sawRemoveTarget = false
    for _, entry in ipairs(securecallInvocations) do
      if entry.fn == _G.ChatFrame_RemoveMessageEventFilter then
        sawRemoveTarget = true
        break
      end
    end
    assert(sawRemoveTarget, "securecall must be invoked with _G.ChatFrame_RemoveMessageEventFilter as the target fn")

    rawset(_G, "ChatFrame_AddMessageEventFilter", savedAdd)
    rawset(_G, "ChatFrame_RemoveMessageEventFilter", savedRemove)
    rawset(_G, "securecall", savedSecurecall)
  end

  -- test_register_falls_back_when_securecall_missing

  -- Test harness and Classic flavors may not provide _G.securecall. The
  -- ChatFilters module must fall back to direct calls rather than
  -- erroring. Fallback is NOT preferred in Retail (it reintroduces the
  -- taint), but it must not break in environments without securecall.
  do
    local savedAdd = _G.ChatFrame_AddMessageEventFilter
    local savedSecurecall = _G.securecall

    local calls = 0
    rawset(_G, "ChatFrame_AddMessageEventFilter", function()
      calls = calls + 1
    end)
    rawset(_G, "securecall", nil)

    local Bootstrap = {
      _inCompetitiveContent = false,
      _inMythicContent = false,
      _inEncounter = false,
    }
    ChatFilters.Configure(Bootstrap, { settings = { hideFromDefaultChat = true } })
    Bootstrap.syncChatFilters()

    assert(calls == 4, "fallback should still register 4 filters when securecall missing, got " .. calls)
    assert(Bootstrap._filtersRegistered == true, "flag should reflect registration")

    rawset(_G, "ChatFrame_AddMessageEventFilter", savedAdd)
    rawset(_G, "securecall", savedSecurecall)
  end
  -- test_registers_through_chat_frame_util_without_globals

  -- The ChatFrame_* globals are deprecated aliases that the next expansion
  -- removes. With only ChatFrameUtil present the whisper filters must still
  -- register and unregister.
  do
    local savedAdd = _G.ChatFrame_AddMessageEventFilter
    local savedRemove = _G.ChatFrame_RemoveMessageEventFilter
    local savedUtil = _G.ChatFrameUtil

    local added, removed = {}, {}
    rawset(_G, "ChatFrame_AddMessageEventFilter", nil)
    rawset(_G, "ChatFrame_RemoveMessageEventFilter", nil)
    rawset(_G, "ChatFrameUtil", {
      AddMessageEventFilter = function(event)
        table.insert(added, event)
      end,
      RemoveMessageEventFilter = function(event)
        table.insert(removed, event)
      end,
    })

    local Bootstrap = { _inCompetitiveContent = false, _inMythicContent = false, _inEncounter = false }
    ChatFilters.Configure(Bootstrap, { settings = { hideFromDefaultChat = true } })
    Bootstrap.syncChatFilters()

    assert(Bootstrap._filtersRegistered == true, "filters should register through ChatFrameUtil")
    assert(#added == 4, "expected 4 ChatFrameUtil registrations, got " .. #added)

    Bootstrap._inEncounter = true
    Bootstrap.syncChatFilters()
    assert(Bootstrap._filtersRegistered == false, "filters should unregister during encounter")
    assert(#removed == 4, "expected 4 ChatFrameUtil removals, got " .. #removed)

    rawset(_G, "ChatFrame_AddMessageEventFilter", savedAdd)
    rawset(_G, "ChatFrame_RemoveMessageEventFilter", savedRemove)
    rawset(_G, "ChatFrameUtil", savedUtil)
  end

  -- test_exposes_selective_hiding_on_after_probe

  do
    assert(ChatFilters.SELECTIVE_HIDING == true, "selective hiding is on since the in-game taint probe passed")
  end
end
